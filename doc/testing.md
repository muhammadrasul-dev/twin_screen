# Testing

Fold-aware code is easy to test without a device, because everything
`twin_screen` knows enters through one place: the platform report given to
`TwinScreenScope`. Replace it, and your widgets see any device you want.

## Fake a device with `platformOverride`

```dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twin_screen/twin_screen.dart';

void main() {
  testWidgets('shows two panes on a half-open book foldable', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const TwinScreenScope(
        platformOverride: TwinPlatformState(
          deviceType: TwinDeviceType.foldable,
          posture: TwinPosture.halfOpened,
          hingeAngle: 100,
          displayFeatures: [
            DisplayFeature(
              bounds: Rect.fromLTWH(400, 0, 0, 600),
              type: DisplayFeatureType.fold,
              state: DisplayFeatureState.postureHalfOpened,
            ),
          ],
        ),
        child: MyApp(),
      ),
    );
    await tester.pump(); // TwinPane measures its position after the first frame

    expect(find.byType(MessageList), findsOneWidget);
    expect(find.byType(MessageView), findsOneWidget);
  });
}
```

With `platformOverride` set, the scope does not talk to the platform at all,
so tests are fast and deterministic.

Setting `tester.view.displayFeatures` instead simulates Android, where the
fold comes from Flutter itself.

## Use a real device preset

`TwinSimulatedScreen.resolve` gives you the exact size, safe area, folds and
platform report of a preset in any state:

```dart
Future<void> pumpOn(
  WidgetTester tester,
  TwinDevicePreset preset, {
  TwinPosture posture = TwinPosture.halfOpened,
  Orientation orientation = Orientation.portrait,
  TwinSimulatedSpan span = TwinSimulatedSpan.both,
}) async {
  final screen = TwinSimulatedScreen.resolve(
    preset: preset,
    posture: posture,
    hingeAngle: TwinSimulatorController.defaultAngleFor(posture),
    orientation: orientation,
    span: span,
  );
  tester.view.physicalSize = screen.size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: screen.padding.top, bottom: screen.padding.bottom);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    TwinScreenScope(
      platformOverride: screen.platform.copyWith(displayFeatures: screen.displayFeatures),
      child: const MyApp(),
    ),
  );
  await tester.pump();
}

testWidgets('every preset, every posture', (tester) async {
  for (final preset in TwinDevicePreset.all) {
    for (final posture in [TwinPosture.closed, TwinPosture.halfOpened, TwinPosture.flat]) {
      if (posture == TwinPosture.closed && !preset.hasCover) continue;
      await pumpOn(tester, preset, posture: posture);
      expect(tester.takeException(), isNull, reason: '${preset.name} $posture');
    }
  }
});
```

A loop like this is a cheap way to catch overflows on every foldable shape.

## Drive the simulator in a test

To test behaviour that changes while the app runs (folding mid-session),
wrap the app in `TwinDebugOverlay` with a controller:

```dart
final controller = TwinSimulatorController();
addTearDown(controller.dispose);

await tester.pumpWidget(
  TwinScreenScope(
    platformOverride: TwinPlatformState.fallback,
    child: TwinDebugOverlay(controller: controller, showPanel: false, child: const MyApp()),
  ),
);

controller.simulate(preset: TwinDevicePreset.galaxyZFold, posture: TwinPosture.halfOpened);
await tester.pump();
// ... the app is now on an open Galaxy Z Fold

controller.posture = TwinPosture.closed;
await tester.pump();
// ... and now on its cover screen, with its state kept
```

## Test the pure logic

The rules are plain functions, so you can test your expectations about them
without widgets:

```dart
TwinResolver.resolveMode(
  deviceType: TwinDeviceType.flip,
  posture: TwinPosture.halfOpened,
  isSpanned: true,
  hingeAxis: TwinHingeAxis.horizontal,
  widthClass: WindowWidthClass.compact,
); // TwinScreenMode.tabletop

TwinPaneRects.resolve(
  region: const Rect.fromLTWH(0, 0, 400, 800),
  hinge: null,
  widthClass: WindowWidthClass.compact,
).isSplit; // false
```

## Replace the platform

For the lowest level, replace the platform implementation itself and push
states by hand:

```dart
import 'package:twin_screen/twin_screen_platform_interface.dart';

class FakeTwinPlatform extends TwinScreenPlatform {
  final controller = StreamController<TwinPlatformState>.broadcast();

  @override
  Stream<TwinPlatformState> watchState() => controller.stream;
}

final fake = FakeTwinPlatform();
TwinScreenPlatform.instance = fake;
// pump a TwinScreenScope without platformOverride, then:
fake.controller.add(const TwinPlatformState(deviceType: TwinDeviceType.flip));
await tester.pump(); // delivers the event
await tester.pump(); // builds the new frame
```

Stream events arrive after the frame that is being pumped, so pump twice.

Without any of these, a widget test talks to a platform channel with no
native side. The plugin then reports an ordinary device, but only
asynchronously, so prefer `platformOverride` in tests.

## On real devices and emulators

`example/integration_test` contains integration tests that run against the
native side:

```sh
cd example
flutter test integration_test -d <device>
```
