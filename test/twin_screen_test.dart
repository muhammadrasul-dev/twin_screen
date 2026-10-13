import 'dart:async';
import 'dart:ui' show DisplayFeature;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twin_screen/twin_screen.dart';

import 'helpers.dart';

int modeBuilds = 0;
int angleBuilds = 0;

class ModeReader extends StatelessWidget {
  const ModeReader({super.key});

  @override
  Widget build(BuildContext context) {
    TwinScreen.modeOf(context);
    modeBuilds++;
    return const SizedBox();
  }
}

class AngleReader extends StatelessWidget {
  const AngleReader({super.key});

  @override
  Widget build(BuildContext context) {
    TwinScreen.hingeAngleOf(context);
    angleBuilds++;
    return const SizedBox();
  }
}

void main() {
  group('TwinScreenScope', () {
    testWidgets('injects the plugin fold into MediaQuery for iOS and web', (
      WidgetTester tester,
    ) async {
      setWindowSize(tester, const Size(800, 600));
      final FakeTwinPlatform platform = useFakePlatform();
      late List<DisplayFeature> seen;
      await tester.pumpWidget(
        TwinScreenScope(
          child: Builder(
            builder: (BuildContext context) {
              seen = MediaQuery.displayFeaturesOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, isEmpty);
      platform.emit(bookState());
      // One pump delivers the stream event, the next builds the frame.
      await tester.pump();
      await tester.pump();
      expect(seen, <DisplayFeature>[verticalFold(400, 600)]);
    });

    testWidgets('keeps a fold Flutter already reports and does not duplicate it', (
      WidgetTester tester,
    ) async {
      setWindowSize(tester, const Size(800, 600));
      tester.view.displayFeatures = <DisplayFeature>[verticalFold(400, 600)];
      final FakeTwinPlatform platform = useFakePlatform();
      late List<DisplayFeature> seen;
      late TwinScreenData data;
      await tester.pumpWidget(
        TwinScreenScope(
          child: Builder(
            builder: (BuildContext context) {
              seen = MediaQuery.displayFeaturesOf(context);
              data = TwinScreen.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      platform.emit(bookState());
      await tester.pump();
      expect(seen, hasLength(1));
      expect(data.source, TwinDataSource.flutter);
      expect(data.mode, TwinScreenMode.book);
    });

    testWidgets("Flutter's DisplayFeatureSubScreen sees the injected fold", (
      WidgetTester tester,
    ) async {
      setWindowSize(tester, const Size(800, 600));
      await tester.pumpWidget(
        TwinScreenScope(
          platformOverride: bookState(),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: DisplayFeatureSubScreen(
              anchorPoint: Offset(700, 300),
              child: SizedBox.expand(key: Key('sub')),
            ),
          ),
        ),
      );
      expect(tester.getRect(find.byKey(const Key('sub'))), const Rect.fromLTRB(400, 0, 800, 600));
    });

    testWidgets("Flutter's showDialog(anchorPoint:) opens on the anchor's side", (
      WidgetTester tester,
    ) async {
      setWindowSize(tester, const Size(800, 600));
      late BuildContext context;
      await tester.pumpWidget(
        TwinScreenScope(
          platformOverride: bookState(),
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext c) {
                context = c;
                return const Scaffold();
              },
            ),
          ),
        ),
      );
      unawaited(
        showDialog<void>(
          context: context,
          anchorPoint: const Offset(100, 300),
          builder: (_) => const AlertDialog(title: Text('hi')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(AlertDialog)).right, lessThanOrEqualTo(400));
    });

    testWidgets('remembers a foldable revealed by a fold', (WidgetTester tester) async {
      setWindowSize(tester, const Size(707, 823));
      tester.view.displayFeatures = <DisplayFeature>[verticalFold(353.5, 823)];
      final FakeTwinPlatform platform = useFakePlatform();
      late TwinScreenData data;
      await tester.pumpWidget(
        TwinScreenScope(
          child: Builder(
            builder: (BuildContext context) {
              data = TwinScreen.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      platform.emit(TwinPlatformState.fallback.copyWith(rotationQuarterTurns: () => 0));
      await tester.pump();
      expect(data.deviceType, TwinDeviceType.foldable);
      expect(platform.remembered, <TwinDeviceType>[TwinDeviceType.foldable]);

      // The fold leaves the window (closed onto the cover screen): the
      // hardware type stays.
      tester.view.displayFeatures = <DisplayFeature>[];
      tester.view.physicalSize = const Size(369, 905);
      await tester.pump();
      expect(data.deviceType, TwinDeviceType.foldable);
      expect(data.mode, TwinScreenMode.cover);
      expect(platform.remembered, hasLength(1));
    });

    testWidgets('remembers a type that corrects the platform guess', (WidgetTester tester) async {
      setWindowSize(tester, const Size(673.5, 841.1));
      tester.view.displayFeatures = <DisplayFeature>[verticalFold(336.8, 841.1)];
      final FakeTwinPlatform platform = useFakePlatform();
      late TwinScreenData data;
      await tester.pumpWidget(
        TwinScreenScope(
          child: Builder(
            builder: (BuildContext context) {
              data = TwinScreen.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      platform.emit(
        const TwinPlatformState(
          deviceType: TwinDeviceType.flip,
          posture: TwinPosture.halfOpened,
          rotationQuarterTurns: 0,
          source: TwinDataSource.plugin,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(data.deviceType, TwinDeviceType.foldable);
      expect(platform.remembered, <TwinDeviceType>[TwinDeviceType.foldable]);

      // Closed: no fold, the platform still guesses flip. The learned type wins.
      tester.view.displayFeatures = <DisplayFeature>[];
      platform.emit(
        const TwinPlatformState(
          deviceType: TwinDeviceType.flip,
          posture: TwinPosture.closed,
          rotationQuarterTurns: 0,
          source: TwinDataSource.plugin,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(data.deviceType, TwinDeviceType.foldable);
      expect(data.mode, TwinScreenMode.cover);
    });

    testWidgets('readers of one aspect do not rebuild when another changes', (
      WidgetTester tester,
    ) async {
      setWindowSize(tester, const Size(800, 600));
      modeBuilds = 0;
      angleBuilds = 0;
      Widget app(double angle) => TwinScreenScope(
        platformOverride: bookState(angle: angle),
        child: const Column(children: <Widget>[ModeReader(), AngleReader()]),
      );
      await tester.pumpWidget(app(100));
      await tester.pumpWidget(app(110));
      await tester.pumpWidget(app(120));
      expect(modeBuilds, 1);
      expect(angleBuilds, 3);
    });

    testWidgets('hingeAngleStreamOf emits the current and later angles', (
      WidgetTester tester,
    ) async {
      setWindowSize(tester, const Size(800, 600));
      late BuildContext context;
      Widget app(double angle) => TwinScreenScope(
        platformOverride: bookState(angle: angle),
        child: Builder(
          builder: (BuildContext c) {
            context = c;
            return const SizedBox();
          },
        ),
      );
      await tester.pumpWidget(app(100));
      final List<double?> angles = <double?>[];
      TwinScreen.hingeAngleStreamOf(context).listen(angles.add);
      await tester.pump();
      await tester.pumpWidget(app(130));
      await tester.pump();
      expect(angles, <double?>[100, 130]);
    });

    testWidgets('keeps the app state when the platform starts reporting a fold', (
      WidgetTester tester,
    ) async {
      setWindowSize(tester, const Size(800, 600));
      final FakeTwinPlatform fake = useFakePlatform();
      int created = 0;
      await tester.pumpWidget(TwinScreenScope(child: StateProbe(onCreate: () => created++)));
      fake.emit(
        const TwinPlatformState(deviceType: TwinDeviceType.foldable, posture: TwinPosture.closed),
      );
      await tester.pump();
      await tester.pump();
      fake.emit(bookState());
      await tester.pump();
      await tester.pump();
      expect(MediaQuery.of(tester.element(find.byType(StateProbe))).displayFeatures, hasLength(1));
      expect(created, 1);
    });

    testWidgets('hingeAngleStreamOf does not miss a change right after listening', (
      WidgetTester tester,
    ) async {
      setWindowSize(tester, const Size(800, 600));
      final FakeTwinPlatform fake = useFakePlatform();
      late BuildContext context;
      await tester.pumpWidget(
        TwinScreenScope(
          child: Builder(
            builder: (BuildContext c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      fake.emit(bookState());
      await tester.pump();
      await tester.pump();
      final List<double?> angles = <double?>[];
      TwinScreen.hingeAngleStreamOf(context).listen(angles.add);
      fake.emit(bookState(angle: 120));
      await tester.pump();
      await tester.pump();
      expect(angles, <double?>[100, 120]);
    });

    testWidgets('a nested scope applies its own breakpoints', (WidgetTester tester) async {
      setWindowSize(tester, const Size(700, 600));
      late WindowClass outer;
      late WindowClass inner;
      await tester.pumpWidget(
        TwinScreenScope(
          platformOverride: TwinPlatformState.fallback,
          child: Column(
            children: <Widget>[
              Builder(
                builder: (BuildContext c) {
                  outer = WindowClass.of(c);
                  return const SizedBox();
                },
              ),
              TwinScreenScope(
                breakpoints: const WindowClassBreakpoints(mediumWidth: 800, expandedWidth: 1200),
                child: Builder(
                  builder: (BuildContext c) {
                    inner = WindowClass.of(c);
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      );
      expect(outer.width, WindowWidthClass.medium);
      expect(inner.width, WindowWidthClass.compact);
    });

    testWidgets('TwinScreen.of works without a scope from MediaQuery alone', (
      WidgetTester tester,
    ) async {
      setWindowSize(tester, const Size(800, 600));
      tester.view.displayFeatures = <DisplayFeature>[verticalFold(400, 600)];
      late TwinScreenData data;
      await tester.pumpWidget(
        Builder(
          builder: (BuildContext context) {
            data = TwinScreen.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(data.mode, TwinScreenMode.book);
      expect(data.source, TwinDataSource.flutter);
    });
  });

  group('WindowClass', () {
    test('Material 3 breakpoints', () {
      const WindowClassBreakpoints b = WindowClassBreakpoints.material3;
      expect(b.widthClassOf(599.9), WindowWidthClass.compact);
      expect(b.widthClassOf(600), WindowWidthClass.medium);
      expect(b.widthClassOf(839.9), WindowWidthClass.medium);
      expect(b.widthClassOf(840), WindowWidthClass.expanded);
      expect(b.heightClassOf(479.9), WindowHeightClass.compact);
      expect(b.heightClassOf(480), WindowHeightClass.medium);
      expect(b.heightClassOf(900), WindowHeightClass.expanded);
      expect(WindowWidthClass.medium >= WindowWidthClass.compact, isTrue);
      expect(WindowWidthClass.medium < WindowWidthClass.expanded, isTrue);
    });

    testWidgets('WindowClassBuilder falls back to smaller classes', (WidgetTester tester) async {
      Future<String> shown(Size size) async {
        setWindowSize(tester, size);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: WindowClassBuilder(
              compact: (_) => const Text('compact'),
              medium: (_) => const Text('medium'),
            ),
          ),
        );
        return tester.widget<Text>(find.byType(Text)).data!;
      }

      expect(await shown(const Size(400, 800)), 'compact');
      expect(await shown(const Size(700, 800)), 'medium');
      expect(await shown(const Size(1000, 800)), 'medium');
    });

    testWidgets('WindowClassBuilder.custom gets width and height', (WidgetTester tester) async {
      setWindowSize(tester, const Size(1000, 400));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WindowClassBuilder.custom(
            builder: (_, WindowClass c) => Text('${c.width.name} ${c.height.name}'),
          ),
        ),
      );
      expect(find.text('expanded compact'), findsOneWidget);
    });
  });
}
