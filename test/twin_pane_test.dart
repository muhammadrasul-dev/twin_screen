import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twin_screen/twin_screen.dart';

import 'helpers.dart';

const Key startKey = Key('start');
const Key endKey = Key('end');

Widget pane({
  TwinPaneFallback fallback = TwinPaneFallback.windowClass,
  TextDirection direction = TextDirection.ltr,
}) => Directionality(
  textDirection: direction,
  child: TwinPane(
    fallback: fallback,
    start: const SizedBox.expand(key: startKey),
    end: const SizedBox.expand(key: endKey),
  ),
);

Future<void> pumpPane(
  WidgetTester tester, {
  required Size size,
  TwinDevicePreset? preset,
  TwinPosture posture = TwinPosture.halfOpened,
  Orientation orientation = Orientation.portrait,
  TwinPlatformState? platform,
  Widget? child,
}) async {
  TwinPlatformState state = platform ?? TwinPlatformState.fallback;
  Size window = size;
  if (preset != null) {
    final TwinSimulatedScreen screen = TwinSimulatedScreen.resolve(
      preset: preset,
      posture: posture,
      hingeAngle: TwinSimulatorController.defaultAngleFor(posture),
      orientation: orientation,
      span: TwinSimulatedSpan.both,
    );
    window = screen.size;
    state = screen.platform.copyWith(displayFeatures: screen.displayFeatures);
  }
  setWindowSize(tester, window);
  await tester.pumpWidget(TwinScreenScope(platformOverride: state, child: child ?? pane()));
  await tester.pump();
}

void main() {
  testWidgets('splits exactly at a half-opened vertical fold (Galaxy Z Fold, book)', (
    WidgetTester tester,
  ) async {
    await pumpPane(tester, size: Size.zero, preset: TwinDevicePreset.galaxyZFold);
    expect(tester.getRect(find.byKey(startKey)), const Rect.fromLTRB(0, 0, 353.5, 823));
    expect(tester.getRect(find.byKey(endKey)), const Rect.fromLTRB(353.5, 0, 707, 823));
  });

  testWidgets('splits at a horizontal fold, start on top (Galaxy Z Flip, tabletop)', (
    WidgetTester tester,
  ) async {
    await pumpPane(tester, size: Size.zero, preset: TwinDevicePreset.galaxyZFlip);
    expect(tester.getRect(find.byKey(startKey)), const Rect.fromLTRB(0, 0, 411, 503));
    expect(tester.getRect(find.byKey(endKey)), const Rect.fromLTRB(0, 503, 411, 1006));
  });

  testWidgets('iPhone Duo: book in landscape, tabletop in portrait', (WidgetTester tester) async {
    await pumpPane(
      tester,
      size: Size.zero,
      preset: TwinDevicePreset.iPhoneDuo,
      orientation: Orientation.landscape,
    );
    expect(tester.getRect(find.byKey(startKey)).right, 475.5);
    expect(tester.getRect(find.byKey(endKey)).left, 475.5);

    await pumpPane(tester, size: Size.zero, preset: TwinDevicePreset.iPhoneDuo);
    expect(tester.getRect(find.byKey(startKey)).bottom, 475.5);
    expect(tester.getRect(find.byKey(endKey)).top, 475.5);
  });

  testWidgets('never puts content under a physical hinge (Surface Duo)', (
    WidgetTester tester,
  ) async {
    await pumpPane(
      tester,
      size: Size.zero,
      preset: TwinDevicePreset.surfaceDuo,
      posture: TwinPosture.flat,
      orientation: Orientation.landscape,
    );
    expect(tester.getRect(find.byKey(startKey)), const Rect.fromLTRB(0, 0, 540, 720));
    expect(tester.getRect(find.byKey(endKey)), const Rect.fromLTRB(574, 0, 1114, 720));
  });

  testWidgets('RTL puts start on the right of a vertical fold', (WidgetTester tester) async {
    setWindowSize(tester, const Size(800, 600));
    await tester.pumpWidget(
      TwinScreenScope(
        platformOverride: bookState(),
        child: pane(direction: TextDirection.rtl),
      ),
    );
    await tester.pump();
    expect(tester.getRect(find.byKey(startKey)), const Rect.fromLTRB(400, 0, 800, 600));
    expect(tester.getRect(find.byKey(endKey)), const Rect.fromLTRB(0, 0, 400, 600));
  });

  testWidgets('a flat fold aligns the split on a medium window (Pixel Fold)', (
    WidgetTester tester,
  ) async {
    await pumpPane(
      tester,
      size: Size.zero,
      preset: TwinDevicePreset.pixelFold,
      posture: TwinPosture.flat,
      orientation: Orientation.landscape,
    );
    expect(tester.getRect(find.byKey(startKey)).right, 420.5);
    expect(tester.getRect(find.byKey(endKey)).left, 420.5);
  });

  testWidgets('a flat fold on a compact window shows start only (Galaxy Z Flip)', (
    WidgetTester tester,
  ) async {
    await pumpPane(
      tester,
      size: Size.zero,
      preset: TwinDevicePreset.galaxyZFlip,
      posture: TwinPosture.flat,
    );
    expect(find.byKey(startKey), findsOneWidget);
    expect(find.byKey(endKey), findsNothing);
  });

  testWidgets('without a fold follows the window class', (WidgetTester tester) async {
    await pumpPane(tester, size: const Size(400, 800));
    expect(find.byKey(endKey), findsNothing);
    await pumpPane(tester, size: const Size(1000, 800));
    expect(tester.getRect(find.byKey(startKey)), const Rect.fromLTRB(0, 0, 500, 800));
    expect(tester.getRect(find.byKey(endKey)), const Rect.fromLTRB(500, 0, 1000, 800));
  });

  testWidgets('cover screen shows start only', (WidgetTester tester) async {
    await pumpPane(
      tester,
      size: Size.zero,
      preset: TwinDevicePreset.galaxyZFold,
      posture: TwinPosture.closed,
    );
    expect(find.byKey(startKey), findsOneWidget);
    expect(find.byKey(endKey), findsNothing);
  });

  testWidgets('explicit fallbacks', (WidgetTester tester) async {
    setWindowSize(tester, const Size(400, 800));
    for (final TwinPaneFallback fallback in TwinPaneFallback.values) {
      await tester.pumpWidget(
        TwinScreenScope(
          platformOverride: TwinPlatformState.fallback,
          child: pane(fallback: fallback),
        ),
      );
      await tester.pump();
      final bool start = find.byKey(startKey).evaluate().isNotEmpty;
      final bool end = find.byKey(endKey).evaluate().isNotEmpty;
      switch (fallback) {
        case TwinPaneFallback.windowClass:
        case TwinPaneFallback.startOnly:
          expect((start, end), (true, false), reason: '$fallback');
        case TwinPaneFallback.endOnly:
          expect((start, end), (false, true), reason: '$fallback');
        case TwinPaneFallback.sideBySide:
          expect(tester.getRect(find.byKey(endKey)).left, 200, reason: '$fallback');
        case TwinPaneFallback.stacked:
          expect(tester.getRect(find.byKey(endKey)).top, 400, reason: '$fallback');
      }
    }
  });

  testWidgets('inside a Scaffold body it measures its own position', (WidgetTester tester) async {
    setWindowSize(tester, const Size(800, 600));
    await tester.pumpWidget(
      TwinScreenScope(
        platformOverride: bookState(),
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('x')),
            body: const TwinPane(
              start: SizedBox.expand(key: startKey),
              end: SizedBox.expand(key: endKey),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.getRect(find.byKey(startKey)), const Rect.fromLTRB(0, 56, 400, 600));
    expect(tester.getRect(find.byKey(endKey)), const Rect.fromLTRB(400, 56, 800, 600));
  });

  testWidgets('each pane sees only its own padding and features', (WidgetTester tester) async {
    setWindowSize(tester, const Size(800, 600));
    tester.view.padding = const FakeViewPadding(left: 30, right: 40);
    late MediaQueryData startQuery;
    late MediaQueryData endQuery;
    await tester.pumpWidget(
      TwinScreenScope(
        platformOverride: bookState(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: TwinPane(
            start: Builder(
              builder: (BuildContext c) {
                startQuery = MediaQuery.of(c);
                return const SizedBox();
              },
            ),
            end: Builder(
              builder: (BuildContext c) {
                endQuery = MediaQuery.of(c);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(startQuery.padding.left, 30);
    expect(startQuery.padding.right, 0);
    expect(endQuery.padding.left, 0);
    expect(endQuery.padding.right, 40);
    expect(startQuery.displayFeatures, isEmpty);
    expect(endQuery.displayFeatures, isEmpty);
  });

  testWidgets('the start pane keeps its state when the split appears', (WidgetTester tester) async {
    setWindowSize(tester, const Size(800, 600));
    final FakeTwinPlatform fake = useFakePlatform();
    int created = 0;
    await tester.pumpWidget(
      TwinScreenScope(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: TwinPane(
            fallback: TwinPaneFallback.startOnly,
            start: StateProbe(onCreate: () => created++),
            end: const SizedBox.expand(key: endKey),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(endKey), findsNothing);
    fake.emit(bookState());
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(endKey), findsOneWidget);
    expect(created, 1);
  });

  test('TwinPaneRects ignores a hinge outside the region', () {
    final TwinPaneRects rects = TwinPaneRects.resolve(
      region: const Rect.fromLTWH(0, 0, 400, 600),
      hinge: TwinHinge.fromDisplayFeature(verticalFold(500, 600), const Size(800, 600)),
      widthClass: WindowWidthClass.compact,
    );
    expect(rects.isSplit, isFalse);
  });

  testWidgets('isSplitOf follows the layout from inside a pane', (WidgetTester tester) async {
    bool? seen;
    Widget probe() => Builder(
      builder: (BuildContext context) {
        seen = TwinPane.isSplitOf(context);
        return const SizedBox.expand();
      },
    );
    Widget pane() => Directionality(
      textDirection: TextDirection.ltr,
      child: TwinPane(start: probe(), end: const SizedBox.expand()),
    );

    await pumpPane(tester, size: const Size(400, 800), child: pane());
    expect(seen, isFalse);

    await pumpPane(tester, size: const Size(800, 600), platform: bookState(), child: pane());
    expect(seen, isTrue);

    expect(TwinPane.isSplitOf(tester.element(find.byType(TwinPane))), isFalse);
  });

  group('hiddenPane', () {
    Future<void> pumpWith(WidgetTester tester, TwinHiddenPane mode, Size size) => pumpPane(
      tester,
      size: size,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: TwinPane(
          hiddenPane: mode,
          start: const SizedBox.expand(key: startKey),
          end: const SizedBox.expand(key: endKey),
        ),
      ),
    );

    testWidgets('dispose builds only the visible pane', (WidgetTester tester) async {
      await pumpWith(tester, TwinHiddenPane.dispose, const Size(400, 800));
      expect(find.byKey(endKey, skipOffstage: false), findsNothing);
    });

    testWidgets('keep builds the hidden pane from the start', (WidgetTester tester) async {
      await pumpWith(tester, TwinHiddenPane.keep, const Size(400, 800));
      expect(find.byKey(endKey), findsNothing);
      expect(find.byKey(endKey, skipOffstage: false), findsOneWidget);
    });

    testWidgets('keepOnceShown keeps a pane only after it was shown', (WidgetTester tester) async {
      await pumpWith(tester, TwinHiddenPane.keepOnceShown, const Size(400, 800));
      expect(find.byKey(endKey, skipOffstage: false), findsNothing, reason: 'never shown yet');

      await pumpWith(tester, TwinHiddenPane.keepOnceShown, const Size(900, 800));
      expect(find.byKey(endKey), findsOneWidget);

      await pumpWith(tester, TwinHiddenPane.keepOnceShown, const Size(400, 800));
      expect(find.byKey(endKey), findsNothing);
      expect(find.byKey(endKey, skipOffstage: false), findsOneWidget, reason: 'kept once shown');
    });
  });
}
