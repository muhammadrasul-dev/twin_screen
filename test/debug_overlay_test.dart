import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twin_screen/twin_screen.dart';

import 'helpers.dart';

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    final TwinScreenData data = TwinScreen.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: GestureDetector(
        onTap: () => setState(() => count++),
        child: Text('${data.mode.name} ${data.size.width.round()} $count', key: const Key('app')),
      ),
    );
  }
}

Future<void> tapChoice(WidgetTester tester, String key) async {
  final Finder finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

String appText(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('app'))).data!;

void main() {
  testWidgets('disabled overlay returns the app unchanged', (WidgetTester tester) async {
    await tester.pumpWidget(
      const TwinScreenScope(
        platformOverride: TwinPlatformState.fallback,
        child: TwinDebugOverlay(enabled: false, child: Counter()),
      ),
    );
    expect(find.byIcon(Icons.devices_fold), findsNothing);
    expect(find.byType(CustomPaint), findsNothing);
  });

  testWidgets('simulates every preset through the controller', (WidgetTester tester) async {
    setWindowSize(tester, const Size(1200, 1200));
    final TwinSimulatorController controller = TwinSimulatorController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      TwinScreenScope(
        platformOverride: TwinPlatformState.fallback,
        child: TwinDebugOverlay(controller: controller, showPanel: false, child: const Counter()),
      ),
    );
    expect(appText(tester), 'standard 1200 0');

    controller.simulate(
      preset: TwinDevicePreset.galaxyZFold,
      posture: TwinPosture.halfOpened,
      orientation: Orientation.portrait,
    );
    await tester.pump();
    expect(appText(tester), 'book 707 0');

    controller.posture = TwinPosture.closed;
    await tester.pump();
    expect(appText(tester), 'cover 369 0');

    controller.simulate(
      preset: TwinDevicePreset.iPhoneDuo,
      posture: TwinPosture.halfOpened,
      orientation: Orientation.landscape,
    );
    await tester.pump();
    expect(appText(tester), 'book 951 0');

    controller.orientation = Orientation.portrait;
    await tester.pump();
    expect(appText(tester), 'tabletop 669 0');

    controller.simulate(preset: TwinDevicePreset.galaxyZFlip, posture: TwinPosture.flat);
    await tester.pump();
    expect(appText(tester), 'dualPane 411 0');

    controller.span = TwinSimulatedSpan.start;
    await tester.pump();
    expect(appText(tester), 'singlePane 411 0');

    controller.stop();
    await tester.pump();
    expect(appText(tester), 'standard 1200 0');
  });

  testWidgets('keeps the app state when the simulator turns on and off', (
    WidgetTester tester,
  ) async {
    setWindowSize(tester, const Size(1200, 1200));
    final TwinSimulatorController controller = TwinSimulatorController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      TwinScreenScope(
        platformOverride: TwinPlatformState.fallback,
        child: TwinDebugOverlay(controller: controller, showPanel: false, child: const Counter()),
      ),
    );
    await tester.tap(find.byKey(const Key('app')));
    await tester.pump();
    controller.simulate(preset: TwinDevicePreset.pixelFold);
    await tester.pump();
    await tester.tap(find.byKey(const Key('app')));
    await tester.pump();
    controller.stop();
    await tester.pump();
    expect(appText(tester), endsWith(' 2'));
  });

  testWidgets('the panel shows the state and drives the simulator', (WidgetTester tester) async {
    setWindowSize(tester, const Size(1200, 1600));
    await tester.pumpWidget(
      const TwinScreenScope(
        platformOverride: TwinPlatformState.fallback,
        child: TwinDebugOverlay(child: Counter()),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('twin_debug_overlay.button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('twin_debug_overlay.info')), findsOneWidget);
    expect(find.text('standard'), findsWidgets);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey<String>('twin_debug_overlay.simulate')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    expect(appText(tester), startsWith('dualPane 707'));

    await tapChoice(tester, 'twin_debug_overlay.choice.Surface Duo');
    await tester.pumpAndSettle();
    expect(appText(tester), startsWith('dualPane 720'));

    await tapChoice(tester, 'twin_debug_overlay.choice.half-open');
    await tester.pumpAndSettle();
    expect(appText(tester), startsWith('tabletop 720'));

    await tapChoice(tester, 'twin_debug_overlay.choice.landscape');
    await tester.pumpAndSettle();
    expect(appText(tester), startsWith('book 1114'));

    await tester.tap(find.byKey(const ValueKey<String>('twin_debug_overlay.close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('twin_debug_overlay.info')), findsNothing);
  });

  testWidgets('draws over a real fold without blocking taps', (WidgetTester tester) async {
    setWindowSize(tester, const Size(800, 600));
    await tester.pumpWidget(
      TwinScreenScope(
        platformOverride: bookState(),
        child: const TwinDebugOverlay(showPanel: false, child: Counter()),
      ),
    );
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.tap(find.byKey(const Key('app')));
    await tester.pump();
    expect(appText(tester), 'book 800 1');
  });
}
