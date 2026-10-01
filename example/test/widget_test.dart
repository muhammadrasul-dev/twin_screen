import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twin_screen/twin_screen.dart';
import 'package:twin_screen_example/main.dart';

void main() {
  testWidgets('the example splits its demos across a half-opened fold', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(707, 823);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final TwinSimulatedScreen screen = TwinSimulatedScreen.resolve(
      preset: TwinDevicePreset.galaxyZFold,
      posture: TwinPosture.halfOpened,
      hingeAngle: 110,
      orientation: Orientation.portrait,
      span: TwinSimulatedSpan.both,
    );
    await tester.pumpWidget(
      TwinScreenScope(
        platformOverride: screen.platform.copyWith(
          displayFeatures: screen.displayFeatures,
        ),
        child: const ExampleApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Half-open like a book'), findsOneWidget);
    // The list is on the start pane and the first demo on the end pane.
    expect(tester.getTopLeft(find.text('twin_screen')).dx, lessThan(353.5));
    expect(tester.getTopLeft(find.text('mode')).dx, greaterThan(353.5));
  });

  testWidgets('on a phone the demos open as pages', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const TwinScreenScope(
        platformOverride: TwinPlatformState.fallback,
        child: ExampleApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('mode'), findsNothing);
    await tester.tap(find.text('Screen state'));
    await tester.pumpAndSettle();
    expect(find.text('mode'), findsOneWidget);
  });
}
