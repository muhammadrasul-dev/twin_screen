import 'dart:async';
import 'dart:ui' show DisplayFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../twin_screen_platform_interface.dart';
import '../core/twin_resolver.dart';
import '../models/twin_enums.dart';
import '../models/twin_hinge.dart';
import '../models/twin_screen_data.dart';
import '../models/window_class.dart';
import 'twin_root.dart';

/// The parts of [TwinScreenData] a widget can depend on.
///
/// A widget that reads one aspect rebuilds only when that aspect changes.
/// For example a widget that reads [mode] does not rebuild while the hinge
/// angle moves.
enum TwinAspect {
  /// [TwinScreenData.deviceType].
  deviceType,

  /// [TwinScreenData.posture].
  posture,

  /// [TwinScreenData.isSpanned].
  spanned,

  /// [TwinScreenData.hinge].
  hinge,

  /// [TwinScreenData.hingeAngle].
  hingeAngle,

  /// [TwinScreenData.segments].
  segments,

  /// [TwinScreenData.windowClass].
  windowClass,

  /// [TwinScreenData.mode].
  mode,

  /// [TwinScreenData.size] and [TwinScreenData.displayFeatures].
  size,

  /// [TwinScreenData.source].
  source;

  bool _changed(TwinScreenData a, TwinScreenData b) => switch (this) {
    deviceType => a.deviceType != b.deviceType,
    posture => a.posture != b.posture,
    spanned => a.isSpanned != b.isSpanned,
    hinge => a.hinge != b.hinge,
    hingeAngle => a.hingeAngle != b.hingeAngle,
    segments => !listEquals(a.segments, b.segments),
    windowClass => a.windowClass != b.windowClass,
    mode => a.mode != b.mode,
    size => a.size != b.size || !listEquals(a.displayFeatures, b.displayFeatures),
    source => a.source != b.source,
  };
}

/// Reads the [TwinScreenData] provided by the nearest [TwinScreenScope].
abstract final class TwinScreen {
  /// The screen data around [context].
  ///
  /// Pass an [aspect] to rebuild only when that part changes.
  ///
  /// Without a [TwinScreenScope] this still works from `MediaQuery` alone, so
  /// Android folds reported by Flutter are seen, but iOS and web folds and
  /// the hardware check are not.
  static TwinScreenData of(BuildContext context, [TwinAspect? aspect]) {
    return maybeOf(context, aspect) ?? _fromMediaQuery(context);
  }

  /// Like [of], but returns null when there is no [TwinScreenScope].
  static TwinScreenData? maybeOf(BuildContext context, [TwinAspect? aspect]) {
    final _TwinScreenModel? model = InheritedModel.inheritFrom<_TwinScreenModel>(
      context,
      aspect: aspect,
    );
    if (model == null) return null;
    return model.data.withTextDirection(Directionality.maybeOf(context) ?? TextDirection.ltr);
  }

  /// The combined mode. Rebuilds only when it changes.
  static TwinScreenMode modeOf(BuildContext context) => of(context, TwinAspect.mode).mode;

  /// The hardware type. Rebuilds only when it changes.
  static TwinDeviceType deviceTypeOf(BuildContext context) =>
      of(context, TwinAspect.deviceType).deviceType;

  /// The hinge posture. Rebuilds only when it changes.
  static TwinPosture postureOf(BuildContext context) => of(context, TwinAspect.posture).posture;

  /// Whether the window spans a fold. Rebuilds only when it changes.
  static bool isSpannedOf(BuildContext context) => of(context, TwinAspect.spanned).isSpanned;

  /// The hinge crossing the window, or null. Rebuilds only when it changes.
  static TwinHinge? hingeOf(BuildContext context) => of(context, TwinAspect.hinge).hinge;

  /// The hinge angle in degrees, or null. Rebuilds on every angle change.
  static double? hingeAngleOf(BuildContext context) =>
      of(context, TwinAspect.hingeAngle).hingeAngle;

  /// The usable segments in start → end order. Rebuilds only when they
  /// change.
  static List<Rect> segmentsOf(BuildContext context) => of(context, TwinAspect.segments).segments;

  /// A stream of hinge angles in degrees, starting with the current value.
  ///
  /// Does not make the caller rebuild. Emits null where there is no hinge
  /// sensor.
  static Stream<double?> hingeAngleStreamOf(BuildContext context) {
    final _TwinScreenModel? model = context.getInheritedWidgetOfExactType<_TwinScreenModel>();
    if (model == null) return Stream<double?>.value(null);
    return model.angles.stream();
  }

  /// The breakpoints of the nearest [TwinScreenScope], or the Material 3
  /// breakpoints without one. Does not make the caller rebuild.
  static WindowClassBreakpoints breakpointsOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_TwinScreenModel>()?.breakpoints ??
      WindowClassBreakpoints.material3;

  static TwinScreenData _fromMediaQuery(BuildContext context) {
    return TwinResolver.resolve(
      size: MediaQuery.sizeOf(context),
      flutterFeatures: MediaQuery.displayFeaturesOf(context),
      platform: const TwinPlatformState(),
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }
}

/// Provides [TwinScreenData] to the app and fills `MediaQuery.displayFeatures`
/// on platforms where Flutter does not.
///
/// Put it above your app:
///
/// ```dart
/// void main() => runApp(const TwinScreenScope(child: MyApp()));
/// ```
///
/// On iOS and web it adds the fold it reads from the platform to
/// `MediaQuery.displayFeatures`, so Flutter's own fold-aware widgets
/// (`DisplayFeatureSubScreen`, `showDialog(anchorPoint: ...)`, popup menus)
/// work there too. Where Flutter already reports the fold (Android), it is
/// kept as is.
///
/// A scope placed inside another scope passes the outer data through,
/// applying its own [breakpoints] if they differ.
class TwinScreenScope extends StatefulWidget {
  /// Creates a scope.
  const TwinScreenScope({
    super.key,
    required this.child,
    this.breakpoints = WindowClassBreakpoints.material3,
    this.injectDisplayFeatures = true,
    this.platformOverride,
  });

  /// The app.
  final Widget child;

  /// The breakpoints used for [WindowClass]. Defaults to Material 3.
  final WindowClassBreakpoints breakpoints;

  /// Whether to add platform folds to `MediaQuery.displayFeatures` for the
  /// widgets below. Defaults to true.
  final bool injectDisplayFeatures;

  /// Replaces the platform report, for tests and the fold simulator.
  ///
  /// When set, the scope does not listen to the platform at all.
  final TwinPlatformState? platformOverride;

  @override
  State<TwinScreenScope> createState() => _TwinScreenScopeState();
}

class _TwinScreenScopeState extends State<TwinScreenScope> {
  StreamSubscription<TwinPlatformState>? _subscription;
  TwinPlatformState _platform = const TwinPlatformState();
  TwinDeviceType? _learnedType;
  late final _AngleSource _angles = _AngleSource();
  bool _nested = false;

  @override
  void initState() {
    super.initState();
    _angles.value = widget.platformOverride?.hingeAngle;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _nested = context.getInheritedWidgetOfExactType<_TwinScreenModel>() != null;
    _syncSubscription();
  }

  @override
  void didUpdateWidget(TwinScreenScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSubscription();
    if (widget.platformOverride != null) _angles.value = widget.platformOverride!.hingeAngle;
  }

  void _syncSubscription() {
    final bool listen = widget.platformOverride == null && !_nested;
    if (listen && _subscription == null) {
      _subscription = TwinScreenPlatform.instance.watchState().listen(_handlePlatform);
    } else if (!listen && _subscription != null) {
      unawaited(_subscription!.cancel());
      _subscription = null;
    }
  }

  void _handlePlatform(TwinPlatformState state) {
    if (!mounted) return;
    _angles.value = state.hingeAngle;
    if (state == _platform) return;
    setState(() => _platform = state);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _angles.close();
    super.dispose();
  }

  TwinPlatformState get _effectivePlatform {
    final TwinPlatformState? override = widget.platformOverride;
    if (override != null) return override;
    final TwinDeviceType? learned = _learnedType;
    if (learned != null && _platform.deviceType != TwinDeviceType.dualScreen) {
      return _platform.copyWith(deviceType: learned);
    }
    return _platform;
  }

  @override
  Widget build(BuildContext context) {
    if (_nested && widget.platformOverride == null) return _buildNested(context);

    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final TwinPlatformState platform = _effectivePlatform;
    final TwinScreenData data = TwinResolver.resolve(
      size: mediaQuery.size,
      flutterFeatures: mediaQuery.displayFeatures,
      platform: platform,
      breakpoints: widget.breakpoints,
    );
    // Remember the type a fold revealed: the hardware does not change when
    // the fold later leaves the window.
    if (widget.platformOverride == null &&
        data.deviceType.isFoldable &&
        data.deviceType != platform.deviceType &&
        _learnedType != data.deviceType) {
      _learnedType = data.deviceType;
      // Lets the native side report the right type next time, even on the
      // cover screen where no fold is visible.
      unawaited(TwinScreenPlatform.instance.rememberDeviceType(data.deviceType));
    }

    Widget result = _TwinScreenModel(
      data: data,
      breakpoints: widget.breakpoints,
      angles: _angles,
      child: widget.child,
    );
    if (widget.injectDisplayFeatures &&
        !listEquals<DisplayFeature>(data.displayFeatures, mediaQuery.displayFeatures)) {
      result = MediaQuery(
        data: mediaQuery.copyWith(displayFeatures: data.displayFeatures),
        child: result,
      );
    }
    return TwinRoot(child: result);
  }

  Widget _buildNested(BuildContext context) {
    final _TwinScreenModel parent = context.dependOnInheritedWidgetOfExactType<_TwinScreenModel>()!;
    if (parent.breakpoints == widget.breakpoints) return widget.child;
    final TwinScreenData outer = parent.data;
    final WindowClass windowClass = widget.breakpoints.classOf(outer.size);
    return _TwinScreenModel(
      data: outer.copyWith(
        windowClass: windowClass,
        mode: TwinResolver.resolveMode(
          deviceType: outer.deviceType,
          posture: outer.posture,
          isSpanned: outer.isSpanned,
          hingeAxis: outer.hinge?.axis,
          widthClass: windowClass.width,
        ),
      ),
      breakpoints: widget.breakpoints,
      angles: parent.angles,
      child: widget.child,
    );
  }
}

/// Holds the latest hinge angle and hands out streams of it.
class _AngleSource {
  final StreamController<double?> _changes = StreamController<double?>.broadcast();
  double? _value;

  set value(double? angle) {
    if (angle == _value) return;
    _value = angle;
    if (!_changes.isClosed) _changes.add(angle);
  }

  Stream<double?> stream() async* {
    yield _value;
    yield* _changes.stream;
  }

  void close() => unawaited(_changes.close());
}

class _TwinScreenModel extends InheritedModel<TwinAspect> {
  const _TwinScreenModel({
    required this.data,
    required this.breakpoints,
    required this.angles,
    required super.child,
  });

  /// Segments in physical (left to right) order.
  final TwinScreenData data;
  final WindowClassBreakpoints breakpoints;
  final _AngleSource angles;

  @override
  bool updateShouldNotify(_TwinScreenModel oldWidget) =>
      oldWidget.data != data || oldWidget.breakpoints != breakpoints;

  @override
  bool updateShouldNotifyDependent(_TwinScreenModel oldWidget, Set<TwinAspect> dependencies) {
    if (oldWidget.breakpoints != breakpoints) return true;
    return dependencies.any((TwinAspect aspect) => aspect._changed(oldWidget.data, data));
  }
}
