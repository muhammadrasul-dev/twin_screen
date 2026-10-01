import Flutter
import UIKit

/// Reports the hinge of iPhone Duo (iOS 27.1+) to Dart: hardware presence,
/// posture, angle, the fold rectangle and the under-display camera.
///
/// The hinge API (`UIHingeInteraction`, `UIView.reservedRegions(kind:options:)`)
/// is reached through the Objective-C runtime, not through the SDK headers.
/// That keeps the plugin compiling with any Xcode, including ones whose SDK
/// predates iOS 27.1, and it simply reports an ordinary device where the API
/// is missing at run time.
public class TwinScreenPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private weak var registrar: FlutterPluginRegistrar?
  private var sink: FlutterEventSink?
  private weak var view: UIView?
  private var interaction: UIInteraction?
  private var boundsObservation: NSKeyValueObservation?
  private var orientationObserver: NSObjectProtocol?
  private var attachAttempts = 0
  private var lastSent: NSDictionary?

  /// Whether the hinge API exists in this iOS version.
  private let hingeAPIAvailable = NSClassFromString("UIHingeInteraction") != nil
  /// Set once the first hinge update arrives: whether the device has a hinge.
  private var hasHinge: Bool?
  private var status = HingeStatus.unknown
  private var angleDegrees: Double?

  /// Mirrors `UIHinge.Status`.
  private enum HingeStatus: Int {
    case unknown = 0
    case closed = 1
    case partiallyOpen = 2
    case fullyOpen = 3
  }

  /// `UIView.ReservedRegionOptions.includeInactive`.
  private static let includeInactive: UInt = 1 << 0

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = TwinScreenPlugin()
    instance.registrar = registrar
    let channel = FlutterMethodChannel(name: "twin_screen", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
    let events = FlutterEventChannel(name: "twin_screen/state", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getState":
      attachIfNeeded()
      result(state())
    case "rememberDeviceType":
      // iOS reports the hinge directly, so there is nothing to remember.
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    lastSent = nil
    attachIfNeeded()
    emitIfChanged()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  deinit {
    detach()
  }

  // MARK: - Attaching to the Flutter view

  private func attachIfNeeded() {
    guard view == nil else { return }
    guard let flutterView = registrar?.viewController?.view else {
      // The view controller may not exist yet during start-up. Try again
      // shortly, a bounded number of times.
      if attachAttempts < 20 {
        attachAttempts += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
          self?.attachIfNeeded()
          self?.emitIfChanged()
        }
      }
      return
    }
    view = flutterView
    boundsObservation = flutterView.layer.observe(\.bounds, options: [.new]) { [weak self] _, _ in
      DispatchQueue.main.async { self?.emitIfChanged() }
    }
    orientationObserver = NotificationCenter.default.addObserver(
      forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.emitIfChanged()
    }
    if let created = makeHingeInteraction() {
      flutterView.addInteraction(created)
      interaction = created
    }
  }

  private func detach() {
    if let interaction = interaction { view?.removeInteraction(interaction) }
    interaction = nil
    boundsObservation?.invalidate()
    boundsObservation = nil
    if let observer = orientationObserver { NotificationCenter.default.removeObserver(observer) }
    orientationObserver = nil
  }

  /// Creates `UIHingeInteraction(updateHandler:)` through the runtime.
  private func makeHingeInteraction() -> UIInteraction? {
    guard let cls = NSClassFromString("UIHingeInteraction") as? NSObject.Type else { return nil }
    let initSelector = NSSelectorFromString("initWithUpdateHandler:")
    guard cls.instancesRespond(to: initSelector),
      let implementation = class_getMethodImplementation(cls, initSelector),
      let allocated = (cls as AnyObject).perform(NSSelectorFromString("alloc"))
    else { return nil }

    // The handler receives the interaction and a `UIHingeInteractionUpdate`.
    let handler: @convention(block) (AnyObject?, AnyObject?) -> Void = { [weak self] _, update in
      DispatchQueue.main.async { self?.handleHingeUpdate(update) }
    }
    // `init` consumes the allocated object and returns a retained one, so
    // both cross as raw pointers and ARC is balanced by hand.
    typealias InitFunction = @convention(c) (UnsafeMutableRawPointer, Selector, AnyObject)
      -> UnsafeMutableRawPointer?
    let initialize = unsafeBitCast(implementation, to: InitFunction.self)
    guard
      let pointer = initialize(
        allocated.toOpaque(), initSelector, unsafeBitCast(handler, to: AnyObject.self))
    else { return nil }
    let object = Unmanaged<AnyObject>.fromOpaque(pointer).takeRetainedValue()
    return object as? UIInteraction
  }

  private func handleHingeUpdate(_ update: AnyObject?) {
    let hinge = Self.property("hinge", of: update) as? NSObject
    if let hinge = hinge {
      hasHinge = true
      let rawStatus = (Self.property("status", of: hinge) as? NSNumber)?.intValue ?? 0
      status = HingeStatus(rawValue: rawStatus) ?? .unknown
      if let radians = (Self.property("angle", of: hinge) as? NSNumber)?.doubleValue, radians.isFinite {
        angleDegrees = radians * 180 / .pi
      } else {
        angleDegrees = nil
      }
    } else {
      hasHinge = false
      status = .unknown
      angleDegrees = nil
    }
    emitIfChanged()
  }

  /// Reads a property through KVC only when the object has its getter, so a
  /// renamed property in a future iOS returns nil instead of crashing.
  private static func property(_ key: String, getter: String? = nil, of object: AnyObject?)
    -> Any?
  {
    guard let object = object as? NSObject,
      object.responds(to: NSSelectorFromString(getter ?? key))
    else { return nil }
    return object.value(forKey: key)
  }

  // MARK: - Reserved regions

  private struct Region {
    let frame: CGRect
    let active: Bool
  }

  /// `view.reservedRegions(kind: .division / .occlusion, options: .includeInactive)`.
  private func reservedRegions(kind kindSelector: String, in view: UIView) -> [Region] {
    guard let kindClass = NSClassFromString("UIViewReservedRegionKind") as? NSObject.Type else {
      return []
    }
    let kindSel = NSSelectorFromString(kindSelector)
    let regionsSel = NSSelectorFromString("reservedRegionsOfKind:options:")
    guard (kindClass as AnyObject).responds(to: kindSel), view.responds(to: regionsSel),
      let kind = (kindClass as AnyObject).perform(kindSel)?.takeUnretainedValue(),
      let implementation = view.method(for: regionsSel)
    else { return [] }

    typealias RegionsFunction = @convention(c) (AnyObject, Selector, AnyObject, UInt) -> AnyObject?
    let regionsOf = unsafeBitCast(implementation, to: RegionsFunction.self)
    guard let regions = regionsOf(view, regionsSel, kind, Self.includeInactive) as? [NSObject] else {
      return []
    }
    return regions.compactMap { region in
      guard let frame = (Self.property("frame", of: region) as? NSValue)?.cgRectValue,
        !frame.isNull, !frame.isInfinite
      else { return nil }
      let active =
        (Self.property("active", getter: "isActive", of: region) as? NSNumber)?.boolValue ?? true
      return Region(frame: frame, active: active)
    }
  }

  // MARK: - State

  private func emitIfChanged() {
    guard let sink = sink else { return }
    let current = state() as NSDictionary
    if let last = lastSent, last.isEqual(current) { return }
    lastSent = current
    sink(current)
  }

  private func state() -> [String: Any] {
    let deviceType: String
    if !hingeAPIAvailable {
      deviceType = "standard"
    } else if let hasHinge = hasHinge {
      deviceType = hasHinge ? "foldable" : "standard"
    } else {
      deviceType = "unknown"
    }

    let posture: String
    switch status {
    case .closed: posture = "closed"
    case .partiallyOpen: posture = "halfOpened"
    case .fullyOpen: posture = "flat"
    case .unknown: posture = "unknown"
    }

    var features: [[String: Any]] = []
    if let view = view, hasHinge == true {
      if status != .closed {
        let foldState: String
        switch status {
        case .partiallyOpen: foldState = "halfOpened"
        case .fullyOpen: foldState = "flat"
        default: foldState = "unknown"
        }
        for region in reservedRegions(kind: "divisionRegionKind", in: view) {
          features.append(Self.feature(region.frame, type: "fold", state: foldState))
        }
      }
      for region in reservedRegions(kind: "occlusionRegionKind", in: view) where region.active {
        features.append(Self.feature(region.frame, type: "cutout", state: "unknown"))
      }
    }

    var result: [String: Any] = [
      "deviceType": deviceType,
      "posture": posture,
      "features": features,
    ]
    if let angle = angleDegrees { result["hingeAngle"] = angle }
    return result
  }

  /// A display feature in Flutter logical pixels, which equal UIKit points in
  /// the Flutter view's coordinate space.
  private static func feature(_ frame: CGRect, type: String, state: String) -> [String: Any] {
    return [
      "left": Double(frame.minX),
      "top": Double(frame.minY),
      "right": Double(frame.maxX),
      "bottom": Double(frame.maxY),
      "type": type,
      "state": state,
    ]
  }
}
