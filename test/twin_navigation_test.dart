import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twin_screen/twin_screen.dart';

import 'helpers.dart';

const Key bodyKey = Key('body');

Future<void> pump(
  WidgetTester tester,
  Size size, {
  TwinPlatformState? platform,
  TwinNavigationLayout layout = TwinNavigationLayout.auto,
  TextDirection direction = TextDirection.ltr,
  ValueChanged<int>? onSelected,
  int selectedIndex = 0,
}) async {
  setWindowSize(tester, size);
  await tester.pumpWidget(
    TwinScreenScope(
      platformOverride: platform ?? TwinPlatformState.fallback,
      child: MaterialApp(
        builder: (BuildContext c, Widget? child) =>
            Directionality(textDirection: direction, child: child!),
        home: Scaffold(
          body: TwinNavigation(
            layout: layout,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected ?? (_) {},
            destinations: const <TwinDestination>[
              TwinDestination(icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
              TwinDestination(icon: Icon(Icons.send_outlined), label: 'Sent'),
              TwinDestination(icon: Icon(Icons.drafts_outlined), label: 'Drafts'),
            ],
            body: const SizedBox.expand(key: bodyKey),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a compact window gets a bottom bar', (WidgetTester tester) async {
    await pump(tester, const Size(400, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.getRect(find.byKey(bodyKey)).bottom, lessThan(800));
  });

  testWidgets('a medium window gets a rail on the start edge', (WidgetTester tester) async {
    await pump(tester, const Size(700, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).extended, isFalse);
    expect(tester.getRect(find.byType(NavigationRail)).left, 0);
    expect(tester.getRect(find.byKey(bodyKey)).left, greaterThan(0));
  });

  testWidgets('the rail is on the right in RTL', (WidgetTester tester) async {
    await pump(tester, const Size(700, 800), direction: TextDirection.rtl);
    expect(tester.getRect(find.byType(NavigationRail)).right, 700);
  });

  testWidgets('an expanded window gets an extended rail', (WidgetTester tester) async {
    await pump(tester, const Size(1000, 800));
    expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).extended, isTrue);
  });

  testWidgets('a separating vertical hinge forces a rail on a compact window', (
    WidgetTester tester,
  ) async {
    await pump(tester, const Size(500, 600), platform: bookState(width: 500));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('a horizontal hinge keeps the bottom bar', (WidgetTester tester) async {
    await pump(
      tester,
      const Size(400, 800),
      platform: TwinPlatformState(
        deviceType: TwinDeviceType.flip,
        posture: TwinPosture.halfOpened,
        displayFeatures: [horizontalFold(400, 400)],
      ),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('layout overrides the choice', (WidgetTester tester) async {
    await pump(tester, const Size(1000, 800), layout: TwinNavigationLayout.bottomBar);
    expect(find.byType(NavigationBar), findsOneWidget);
    await pump(tester, const Size(400, 800), layout: TwinNavigationLayout.rail);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('selecting a destination reports its index', (WidgetTester tester) async {
    int? picked;
    await pump(tester, const Size(400, 800), onSelected: (int i) => picked = i);
    await tester.tap(find.text('Sent'));
    expect(picked, 1);

    await pump(tester, const Size(700, 800), onSelected: (int i) => picked = i);
    await tester.tap(find.text('Drafts'));
    expect(picked, 2);
  });

  test('resolve never returns auto', () {
    for (final WindowWidthClass c in WindowWidthClass.values) {
      for (final bool hinge in <bool>[false, true]) {
        expect(
          TwinNavigation.resolve(
            layout: TwinNavigationLayout.auto,
            widthClass: c,
            hingeSeparatesVertically: hinge,
          ),
          isNot(TwinNavigationLayout.auto),
        );
      }
    }
  });
}
