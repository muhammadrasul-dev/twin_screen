import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twin_screen/twin_screen_platform_interface.dart';

/// A platform whose state the test pushes by hand.
class FakeTwinPlatform extends TwinScreenPlatform {
  final StreamController<TwinPlatformState> controller =
      StreamController<TwinPlatformState>.broadcast();
  final List<TwinDeviceType> remembered = <TwinDeviceType>[];

  void emit(TwinPlatformState state) => controller.add(state);

  @override
  Stream<TwinPlatformState> watchState() => controller.stream;

  @override
  Future<void> rememberDeviceType(TwinDeviceType type) async => remembered.add(type);
}

/// Installs a [FakeTwinPlatform] for one test.
FakeTwinPlatform useFakePlatform() {
  final TwinScreenPlatform previous = TwinScreenPlatform.instance;
  final FakeTwinPlatform fake = FakeTwinPlatform();
  TwinScreenPlatform.instance = fake;
  addTearDown(() => TwinScreenPlatform.instance = previous);
  return fake;
}

/// Sets the test window to [size] logical pixels.
void setWindowSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A vertical fold at x = [x] across a window [height] tall.
DisplayFeature verticalFold(
  double x,
  double height, {
  DisplayFeatureState state = DisplayFeatureState.postureHalfOpened,
}) => DisplayFeature(
  bounds: Rect.fromLTWH(x, 0, 0, height),
  type: DisplayFeatureType.fold,
  state: state,
);

/// A horizontal fold at y = [y] across a window [width] wide.
DisplayFeature horizontalFold(
  double y,
  double width, {
  DisplayFeatureState state = DisplayFeatureState.postureHalfOpened,
}) => DisplayFeature(
  bounds: Rect.fromLTWH(0, y, width, 0),
  type: DisplayFeatureType.fold,
  state: state,
);

/// A half-opened book foldable as the iOS plugin reports it.
TwinPlatformState bookState({double width = 800, double height = 600, double? angle = 100}) =>
    TwinPlatformState(
      deviceType: TwinDeviceType.foldable,
      posture: TwinPosture.halfOpened,
      hingeAngle: angle,
      displayFeatures: <DisplayFeature>[verticalFold(width / 2, height)],
      source: TwinDataSource.plugin,
    );

/// Counts how many times its state is created, to catch subtrees that are
/// rebuilt from scratch.
class StateProbe extends StatefulWidget {
  /// Creates a probe that reports each new state to [onCreate].
  const StateProbe({super.key, required this.onCreate});

  /// Called from `initState`.
  final VoidCallback onCreate;

  @override
  State<StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<StateProbe> {
  @override
  void initState() {
    super.initState();
    widget.onCreate();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
