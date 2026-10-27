import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twin_screen/twin_screen.dart';

import 'helpers.dart';

void main() {
  late BuildContext context;

  Future<void> pumpApp(
    WidgetTester tester, {
    TwinPlatformState? platform,
    TextDirection direction = TextDirection.ltr,
  }) async {
    setWindowSize(tester, const Size(800, 600));
    await tester.pumpWidget(
      TwinScreenScope(
        platformOverride: platform ?? bookState(),
        child: MaterialApp(
          builder: (BuildContext c, Widget? child) =>
              Directionality(textDirection: direction, child: child!),
          home: Builder(
            builder: (BuildContext c) {
              context = c;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
  }

  Future<Rect> open(
    WidgetTester tester, {
    Offset? anchor,
    TwinPaneSide side = TwinPaneSide.start,
    bool spanning = false,
  }) async {
    final Future<void> result = showFoldAwareBottomSheet<void>(
      context: context,
      anchorPoint: anchor,
      preferredSide: side,
      allowSpanning: spanning,
      constraints: const BoxConstraints(maxWidth: 900),
      builder: (_) => const SizedBox(key: Key('sheet'), height: 200, width: 900),
    );
    await tester.pumpAndSettle();
    final Rect rect = tester.getRect(find.byKey(const Key('sheet')));
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await result;
    return rect;
  }

  testWidgets('rises on the side that holds the anchor', (WidgetTester tester) async {
    await pumpApp(tester);
    final Rect right = await open(tester, anchor: const Offset(650, 100));
    expect(right.left, greaterThanOrEqualTo(400));
    final Rect left = await open(tester, anchor: const Offset(50, 100));
    expect(left.right, lessThanOrEqualTo(400));
  });

  testWidgets('uses preferredSide without an anchor', (WidgetTester tester) async {
    await pumpApp(tester);
    expect((await open(tester)).right, lessThanOrEqualTo(400));
    expect((await open(tester, side: TwinPaneSide.end)).left, greaterThanOrEqualTo(400));
  });

  testWidgets('preferredSide start is the right side in RTL', (WidgetTester tester) async {
    await pumpApp(tester, direction: TextDirection.rtl);
    expect((await open(tester)).left, greaterThanOrEqualTo(400));
  });

  testWidgets('allowSpanning covers both sides', (WidgetTester tester) async {
    await pumpApp(tester);
    final Rect rect = await open(tester, spanning: true);
    expect(rect.left, lessThan(400));
    expect(rect.right, greaterThan(400));
  });

  testWidgets('without a fold it spans the window', (WidgetTester tester) async {
    await pumpApp(tester, platform: TwinPlatformState.fallback);
    final Rect rect = await open(tester, anchor: const Offset(650, 100));
    expect(rect.left, lessThan(400));
    expect(rect.right, greaterThan(400));
    expect(rect.bottom, closeTo(600, 1));
  });

  testWidgets('a top/bottom fold keeps the sheet in the bottom half', (WidgetTester tester) async {
    await pumpApp(
      tester,
      platform: TwinPlatformState(
        deviceType: TwinDeviceType.flip,
        posture: TwinPosture.halfOpened,
        displayFeatures: [horizontalFold(300, 800)],
      ),
    );
    final Rect bottom = await open(tester, side: TwinPaneSide.end);
    expect(bottom.top, greaterThanOrEqualTo(300));
  });

  testWidgets('the scrim covers the whole screen and dismisses', (WidgetTester tester) async {
    await pumpApp(tester);
    unawaited(
      showFoldAwareBottomSheet<void>(
        context: context,
        builder: (_) => const SizedBox(key: Key('sheet'), height: 200),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sheet')), findsOneWidget);
    await tester.tapAt(const Offset(700, 20));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sheet')), findsNothing);
  });
}
