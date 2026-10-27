import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/twin_enums.dart';
import '../platform/twin_platform_state.dart';
import 'twin_device_preset.dart';

/// Which part of the unfolded screen the app occupies in the simulator.
enum TwinSimulatedSpan {
  /// The app spans both sides of the fold.
  both,

  /// The app occupies the leading side only (left or top), as in
  /// split-screen.
  start,

  /// The app occupies the trailing side only (right or bottom).
  end,
}

/// Drives the fold simulator of `TwinDebugOverlay`.
///
/// Create one to control the simulator from code, for example in widget
/// tests:
///
/// ```dart
/// final controller = TwinSimulatorController()
///   ..simulate(preset: TwinDevicePreset.galaxyZFold, posture: TwinPosture.halfOpened);
/// await tester.pumpWidget(
///   TwinScreenScope(
///     child: TwinDebugOverlay(controller: controller, child: const MyApp()),
///   ),
/// );
/// ```
class TwinSimulatorController extends ChangeNotifier {
  /// Creates a controller. The simulator starts off unless [enabled] is true.
  /// [orientation] defaults to the preset's natural one.
  TwinSimulatorController({
    bool enabled = false,
    TwinDevicePreset preset = TwinDevicePreset.galaxyZFold,
    TwinPosture posture = TwinPosture.flat,
    Orientation? orientation,
    TwinSimulatedSpan span = TwinSimulatedSpan.both,
  }) : _enabled = enabled,
       _preset = preset,
       _orientation = orientation ?? preset.defaultOrientation,
       _span = span,
       _posture = posture,
       _hingeAngle = defaultAngleFor(posture);

  /// Angles below this count as closed.
  static const double closedBelow = 30;

  /// Angles above this count as flat.
  static const double flatAbove = 150;

  /// The angle the simulator uses for each posture.
  static double defaultAngleFor(TwinPosture posture) => switch (posture) {
    TwinPosture.closed => 0,
    TwinPosture.halfOpened => 110,
    TwinPosture.flat || TwinPosture.unknown => 180,
  };

  /// The posture a hinge [angle] belongs to.
  static TwinPosture postureForAngle(double angle) {
    if (angle < closedBelow) return TwinPosture.closed;
    if (angle > flatAbove) return TwinPosture.flat;
    return TwinPosture.halfOpened;
  }

  bool _enabled;
  TwinDevicePreset _preset;
  TwinPosture _posture;
  double _hingeAngle;
  Orientation _orientation;
  TwinSimulatedSpan _span;

  /// Whether the app is shown inside the simulated device.
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
  }

  /// The simulated device.
  TwinDevicePreset get preset => _preset;
  set preset(TwinDevicePreset value) {
    if (value == _preset) return;
    _preset = value;
    _orientation = value.defaultOrientation;
    if (!value.hasCover && _posture == TwinPosture.closed) _setPosture(TwinPosture.flat);
    notifyListeners();
  }

  /// The simulated posture. Setting it also moves [hingeAngle] to a typical
  /// value for that posture.
  TwinPosture get posture => _posture;
  set posture(TwinPosture value) {
    if (value == _posture) return;
    _setPosture(value);
    notifyListeners();
  }

  /// The simulated hinge angle in degrees (0–180). Setting it also updates
  /// [posture].
  double get hingeAngle => _hingeAngle;
  set hingeAngle(double value) {
    final double angle = value.clamp(0, 180).toDouble();
    if (angle == _hingeAngle) return;
    _hingeAngle = angle;
    TwinPosture posture = postureForAngle(angle);
    if (posture == TwinPosture.closed && !_preset.hasCover) posture = TwinPosture.halfOpened;
    _posture = posture;
    notifyListeners();
  }

  /// The simulated orientation.
  Orientation get orientation => _orientation;
  set orientation(Orientation value) {
    if (value == _orientation) return;
    _orientation = value;
    notifyListeners();
  }

  /// Which part of the unfolded screen the app occupies.
  TwinSimulatedSpan get span => _span;
  set span(TwinSimulatedSpan value) {
    if (value == _span) return;
    _span = value;
    notifyListeners();
  }

  /// Turns the simulator on and sets any of the given values in one go.
  void simulate({
    TwinDevicePreset? preset,
    TwinPosture? posture,
    Orientation? orientation,
    TwinSimulatedSpan? span,
    double? hingeAngle,
  }) {
    _enabled = true;
    if (preset != null) {
      _preset = preset;
      _orientation = preset.defaultOrientation;
    }
    if (orientation != null) _orientation = orientation;
    if (span != null) _span = span;
    if (posture != null) _setPosture(posture);
    if (hingeAngle != null) {
      _hingeAngle = hingeAngle.clamp(0, 180).toDouble();
      if (posture == null) _posture = postureForAngle(_hingeAngle);
    }
    if (!_preset.hasCover && _posture == TwinPosture.closed) _setPosture(TwinPosture.flat);
    notifyListeners();
  }

  /// Turns the simulator off.
  void stop() => enabled = false;

  void _setPosture(TwinPosture value) {
    _posture = value;
    _hingeAngle = defaultAngleFor(value);
  }

  /// The screen the app sees for the current settings.
  TwinSimulatedScreen get screen => TwinSimulatedScreen.resolve(
    preset: _preset,
    posture: _posture,
    hingeAngle: _hingeAngle,
    orientation: _orientation,
    span: _span,
  );
}

/// The screen the simulator presents to the app: its size, safe area,
/// display features and platform report.
@immutable
class TwinSimulatedScreen {
  /// Creates a simulated screen.
  const TwinSimulatedScreen({
    required this.size,
    required this.padding,
    required this.displayFeatures,
    required this.platform,
    required this.isCover,
  });

  /// Works out what the app sees on [preset] in the given state.
  factory TwinSimulatedScreen.resolve({
    required TwinDevicePreset preset,
    required TwinPosture posture,
    required double hingeAngle,
    required Orientation orientation,
    required TwinSimulatedSpan span,
  }) {
    final bool closed = posture == TwinPosture.closed;
    final Size natural = closed ? (preset.coverSize ?? preset.innerSize) : preset.innerSize;
    final Size display = _oriented(natural, orientation);
    // The part of the unfolded screen the app does not cover, at the end of
    // its long side.
    final double inset = closed ? 0 : preset.innerEndInset;
    final Size full = display.width >= display.height
        ? Size(display.width - inset, display.height)
        : Size(display.width, display.height - inset);
    final bool rotated = _orientationOf(natural) != orientation;
    final TwinPlatformState platform = TwinPlatformState(
      deviceType: preset.deviceType,
      posture: posture,
      hingeAngle: hingeAngle,
      rotationQuarterTurns: rotated ? 1 : 0,
      source: TwinDataSource.simulator,
    );
    final EdgeInsets insets = EdgeInsets.only(
      top: preset.statusBarHeight,
      bottom: preset.bottomInset,
    );

    // A closed device shows its cover screen. A dual-screen device without a
    // cover shows one panel, as if folded back.
    if (closed) {
      final Size size = preset.hasCover
          ? full
          : _oriented(
              _halfOf(preset.innerSize, preset.innerHingeAxis, preset.hingeWidth),
              orientation,
            );
      return TwinSimulatedScreen(
        size: size,
        padding: insets,
        displayFeatures: const <DisplayFeature>[],
        platform: platform,
        isCover: true,
      );
    }

    final TwinHingeAxis axis = rotated ? preset.innerHingeAxis.flipped : preset.innerHingeAxis;
    final double hw = preset.hingeWidth;
    // The fold is in the middle of the whole screen, not of the app window.
    final double foldStart =
        ((axis == TwinHingeAxis.vertical ? display.width : display.height) - hw) / 2;
    if (span != TwinSimulatedSpan.both) {
      final bool horizontal = axis == TwinHingeAxis.horizontal;
      final bool isStart = span == TwinSimulatedSpan.start;
      final double extent = isStart
          ? foldStart
          : (horizontal ? full.height : full.width) - foldStart - hw;
      return TwinSimulatedScreen(
        size: horizontal ? Size(full.width, extent) : Size(extent, full.height),
        padding: horizontal
            ? EdgeInsets.only(
                top: isStart ? preset.statusBarHeight : 0,
                bottom: isStart ? 0 : preset.bottomInset,
              )
            : insets,
        displayFeatures: const <DisplayFeature>[],
        platform: platform,
        isCover: false,
      );
    }

    final Rect bounds = axis == TwinHingeAxis.vertical
        ? Rect.fromLTWH(foldStart, 0, hw, full.height)
        : Rect.fromLTWH(0, foldStart, full.width, hw);
    return TwinSimulatedScreen(
      size: full,
      padding: insets,
      displayFeatures: <DisplayFeature>[
        DisplayFeature(
          bounds: bounds,
          type: hw > 0 ? DisplayFeatureType.hinge : DisplayFeatureType.fold,
          state: posture == TwinPosture.halfOpened
              ? DisplayFeatureState.postureHalfOpened
              : DisplayFeatureState.postureFlat,
        ),
      ],
      platform: platform,
      isCover: false,
    );
  }

  /// The window size in logical pixels.
  final Size size;

  /// The safe-area insets.
  final EdgeInsets padding;

  /// The fold or hinge, when the app spans it.
  final List<DisplayFeature> displayFeatures;

  /// The platform report handed to the simulated `TwinScreenScope`.
  final TwinPlatformState platform;

  /// Whether the app is on the cover screen.
  final bool isCover;

  static Orientation _orientationOf(Size size) =>
      size.width > size.height ? Orientation.landscape : Orientation.portrait;

  static Size _oriented(Size size, Orientation orientation) => orientation == Orientation.portrait
      ? Size(size.shortestSide, size.longestSide)
      : Size(size.longestSide, size.shortestSide);

  /// One side of [full], split along a hinge running along [axis].
  static Size _halfOf(Size full, TwinHingeAxis axis, double hingeWidth) =>
      axis == TwinHingeAxis.vertical
      ? Size((full.width - hingeWidth) / 2, full.height)
      : Size(full.width, (full.height - hingeWidth) / 2);

  @override
  bool operator ==(Object other) =>
      other is TwinSimulatedScreen &&
      other.size == size &&
      other.padding == padding &&
      listEquals(other.displayFeatures, displayFeatures) &&
      other.platform == platform &&
      other.isCover == isCover;

  @override
  int get hashCode =>
      Object.hash(size, padding, Object.hashAll(displayFeatures), platform, isCover);
}
