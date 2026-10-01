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
    final Future<void> result = showFoldAwareDialog<void>(
      context: context,
      anchorPoint: anchor,
      preferredSide: side,
      allowSpanning: spanning,
      builder: (_) => const AlertDialog(
        title: Text('hi'),
        content: SizedBox(width: 700, child: Text('wide content')),
      ),
    );
    await tester.pumpAndSettle();
    final Rect rect = tester.getRect(find.byType(AlertDialog));
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    await result;
    return rect;
  }

  testWidgets('opens on the side that holds the anchor', (WidgetTester tester) async {
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

  testWidgets('without a fold it behaves like showDialog', (WidgetTester tester) async {
    await pumpApp(tester, platform: TwinPlatformState.fallback);
    final Rect rect = await open(tester, anchor: const Offset(650, 100));
    expect(rect.center.dx, closeTo(400, 1));
  });

  testWidgets('a top/bottom fold keeps the dialog in one half (tabletop)', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      platform: TwinPlatformState(
        deviceType: TwinDeviceType.flip,
        posture: TwinPosture.halfOpened,
        displayFeatures: [horizontalFold(300, 800)],
      ),
    );
    final Rect bottom = await open(tester, anchor: const Offset(400, 500));
    expect(bottom.top, greaterThanOrEqualTo(300));
  });

  testWidgets('FoldAwareDialog places any child', (WidgetTester tester) async {
    setWindowSize(tester, const Size(800, 600));
    await tester.pumpWidget(
      TwinScreenScope(
        platformOverride: bookState(),
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: FoldAwareDialog(
            preferredSide: TwinPaneSide.end,
            child: SizedBox.expand(key: Key('child')),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.getRect(find.byKey(const Key('child'))), const Rect.fromLTRB(400, 0, 800, 600));
  });
}
