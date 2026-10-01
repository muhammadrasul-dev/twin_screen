import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:twin_screen/twin_screen.dart';

import 'helpers.dart';

void main() {
  group('resolveMode', () {
    TwinScreenMode mode(
      TwinDeviceType device,
      TwinPosture posture, {
      bool spanned = false,
      TwinHingeAxis? axis,
      WindowWidthClass width = WindowWidthClass.medium,
    }) => TwinResolver.resolveMode(
      deviceType: device,
      posture: posture,
      isSpanned: spanned,
      hingeAxis: axis,
      widthClass: width,
    );

    test('ordinary device', () {
      for (final TwinPosture posture in TwinPosture.values) {
        expect(mode(TwinDeviceType.standard, posture), TwinScreenMode.standard);
        expect(mode(TwinDeviceType.unknown, posture), TwinScreenMode.standard);
      }
    });

    test('foldable, not spanned', () {
      for (final TwinDeviceType device in <TwinDeviceType>[
        TwinDeviceType.foldable,
        TwinDeviceType.flip,
        TwinDeviceType.dualScreen,
      ]) {
        expect(mode(device, TwinPosture.closed), TwinScreenMode.cover);
        expect(mode(device, TwinPosture.flat), TwinScreenMode.singlePane);
        expect(mode(device, TwinPosture.halfOpened), TwinScreenMode.singlePane);
        expect(
          mode(device, TwinPosture.unknown, width: WindowWidthClass.compact),
          TwinScreenMode.cover,
        );
        expect(mode(device, TwinPosture.unknown), TwinScreenMode.singlePane);
      }
    });

    test('spanned', () {
      expect(
        mode(
          TwinDeviceType.foldable,
          TwinPosture.flat,
          spanned: true,
          axis: TwinHingeAxis.vertical,
        ),
        TwinScreenMode.dualPane,
      );
      expect(
        mode(TwinDeviceType.flip, TwinPosture.flat, spanned: true, axis: TwinHingeAxis.horizontal),
        TwinScreenMode.dualPane,
      );
      expect(
        mode(
          TwinDeviceType.foldable,
          TwinPosture.halfOpened,
          spanned: true,
          axis: TwinHingeAxis.vertical,
        ),
        TwinScreenMode.book,
      );
      expect(
        mode(
          TwinDeviceType.dualScreen,
          TwinPosture.halfOpened,
          spanned: true,
          axis: TwinHingeAxis.vertical,
        ),
        TwinScreenMode.book,
      );
      expect(
        mode(
          TwinDeviceType.flip,
          TwinPosture.halfOpened,
          spanned: true,
          axis: TwinHingeAxis.horizontal,
        ),
        TwinScreenMode.tabletop,
      );
      expect(
        mode(
          TwinDeviceType.foldable,
          TwinPosture.halfOpened,
          spanned: true,
          axis: TwinHingeAxis.horizontal,
        ),
        TwinScreenMode.tabletop,
      );
    });
  });

  group('resolve', () {
    test('Android: Flutter reports the fold, the plugin only the hardware', () {
      final TwinScreenData data = TwinResolver.resolve(
        size: const Size(701, 841),
        flutterFeatures: <DisplayFeature>[horizontalFold(420.5, 701)],
        platform: const TwinPlatformState(
          deviceType: TwinDeviceType.foldable,
          posture: TwinPosture.halfOpened,
          hingeAngle: 95,
          rotationQuarterTurns: 1,
          source: TwinDataSource.plugin,
        ),
      );
      expect(data.mode, TwinScreenMode.tabletop);
      expect(data.source, TwinDataSource.flutter);
      expect(data.segments, const <Rect>[
        Rect.fromLTRB(0, 0, 701, 420.5),
        Rect.fromLTRB(0, 420.5, 701, 841),
      ]);
      expect(data.hingeAngle, 95);
    });

    test('Android cover screen: no fold, hinge sensor says closed', () {
      final TwinScreenData data = TwinResolver.resolve(
        size: const Size(369, 905),
        flutterFeatures: const <DisplayFeature>[],
        platform: const TwinPlatformState(
          deviceType: TwinDeviceType.foldable,
          posture: TwinPosture.closed,
          hingeAngle: 0,
          source: TwinDataSource.plugin,
        ),
      );
      expect(data.mode, TwinScreenMode.cover);
      expect(data.isSpanned, isFalse);
      expect(data.segments, const <Rect>[Rect.fromLTWH(0, 0, 369, 905)]);
    });

    test('iOS: plugin fold is used and reported as plugin data', () {
      final TwinScreenData data = TwinResolver.resolve(
        size: const Size(800, 600),
        flutterFeatures: const <DisplayFeature>[],
        platform: bookState(),
      );
      expect(data.mode, TwinScreenMode.book);
      expect(data.source, TwinDataSource.plugin);
      expect(data.displayFeatures, hasLength(1));
    });

    test('Android emulator: a 1 px "hinge" reported flat while the sensor reads 100°', () {
      // What the 7.6" Fold-in emulator sends at a 100° hinge angle.
      final TwinScreenData data = TwinResolver.resolve(
        size: const Size(673.5, 841.1),
        flutterFeatures: const <DisplayFeature>[
          DisplayFeature(
            bounds: Rect.fromLTRB(336.8, 0, 337.1, 841.1),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
        platform: const TwinPlatformState(
          deviceType: TwinDeviceType.foldable,
          posture: TwinPosture.halfOpened,
          hingeAngle: 100,
          rotationQuarterTurns: 0,
          source: TwinDataSource.plugin,
        ),
      );
      expect(data.posture, TwinPosture.halfOpened);
      expect(data.mode, TwinScreenMode.book);
      expect(data.deviceType, TwinDeviceType.foldable);
      expect(data.hinge!.occludesContent, isFalse);
      expect(data.hinge!.isPhysicalHinge, isFalse);
      expect(data.hinge!.isSeparating, isTrue);
    });

    test('on Android a fold corrects a wrong hardware guess', () {
      // The native side guessed "flip" while the device was closing.
      final TwinScreenData data = TwinResolver.resolve(
        size: const Size(673.5, 841.1),
        flutterFeatures: <DisplayFeature>[verticalFold(336.8, 841.1)],
        platform: const TwinPlatformState(
          deviceType: TwinDeviceType.flip,
          posture: TwinPosture.halfOpened,
          rotationQuarterTurns: 0,
        ),
      );
      expect(data.deviceType, TwinDeviceType.foldable);
    });

    test('on iOS the reported type is kept (no rotation to judge the fold by)', () {
      final TwinScreenData data = TwinResolver.resolve(
        size: const Size(669, 951),
        flutterFeatures: const <DisplayFeature>[],
        platform: TwinPlatformState(
          deviceType: TwinDeviceType.foldable,
          posture: TwinPosture.halfOpened,
          displayFeatures: <DisplayFeature>[horizontalFold(475.5, 669)],
        ),
      );
      expect(data.deviceType, TwinDeviceType.foldable);
      expect(data.mode, TwinScreenMode.tabletop);
    });

    test('a flat fold with a flat sensor stays flat and does not separate', () {
      final TwinScreenData data = TwinResolver.resolve(
        size: const Size(707, 823),
        flutterFeatures: <DisplayFeature>[
          verticalFold(353.5, 823, state: DisplayFeatureState.postureFlat),
        ],
        platform: const TwinPlatformState(
          deviceType: TwinDeviceType.foldable,
          posture: TwinPosture.flat,
          hingeAngle: 178,
        ),
      );
      expect(data.mode, TwinScreenMode.dualPane);
      expect(data.hasSeparatingHinge, isFalse);
    });

    test('a half-opened fold wins over a sensor that reads flat', () {
      expect(
        TwinResolver.resolvePosture(TwinPosture.flat, DisplayFeatureState.postureHalfOpened),
        TwinPosture.halfOpened,
      );
      expect(TwinResolver.resolvePosture(TwinPosture.closed, null), TwinPosture.closed);
    });

    test('a fold state wins over a stale closed posture', () {
      final TwinScreenData data = TwinResolver.resolve(
        size: const Size(800, 600),
        flutterFeatures: <DisplayFeature>[
          verticalFold(400, 600, state: DisplayFeatureState.unknown),
        ],
        platform: const TwinPlatformState(
          deviceType: TwinDeviceType.foldable,
          posture: TwinPosture.closed,
        ),
      );
      expect(data.posture, TwinPosture.unknown);
      expect(data.mode, TwinScreenMode.dualPane);
    });

    test('segments are ordered start to end for RTL', () {
      final TwinScreenData data = TwinResolver.resolve(
        size: const Size(800, 600),
        flutterFeatures: <DisplayFeature>[verticalFold(400, 600)],
        platform: TwinPlatformState.fallback,
        textDirection: TextDirection.rtl,
      );
      expect(data.startSegment, const Rect.fromLTRB(400, 0, 800, 600));
      expect(data.endSegment, const Rect.fromLTRB(0, 0, 400, 600));
    });

    test('a horizontal hinge keeps top as start in RTL', () {
      final TwinScreenData data = TwinResolver.resolve(
        size: const Size(400, 900),
        flutterFeatures: <DisplayFeature>[horizontalFold(450, 400)],
        platform: TwinPlatformState.fallback,
        textDirection: TextDirection.rtl,
      );
      expect(data.startSegment.top, 0);
    });

    test('custom breakpoints change the window class and the mode', () {
      final TwinScreenData data = TwinResolver.resolve(
        size: const Size(700, 900),
        flutterFeatures: const <DisplayFeature>[],
        platform: const TwinPlatformState(deviceType: TwinDeviceType.foldable),
        breakpoints: const WindowClassBreakpoints(mediumWidth: 720, expandedWidth: 1000),
      );
      expect(data.windowClass.width, WindowWidthClass.compact);
      expect(data.mode, TwinScreenMode.cover);
    });
  });

  group('mergeFeatures', () {
    test('does not duplicate a fold Flutter already reports', () {
      final List<DisplayFeature> merged = TwinResolver.mergeFeatures(
        <DisplayFeature>[verticalFold(400, 600)],
        <DisplayFeature>[verticalFold(400, 600)],
      );
      expect(merged, hasLength(1));
    });

    test('adds plugin cutouts next to a Flutter fold', () {
      const DisplayFeature cutout = DisplayFeature(
        bounds: Rect.fromLTWH(10, 10, 20, 20),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      );
      final List<DisplayFeature> merged = TwinResolver.mergeFeatures(
        <DisplayFeature>[verticalFold(400, 600)],
        <DisplayFeature>[verticalFold(400, 600), cutout],
      );
      expect(merged, hasLength(2));
      expect(merged.last, cutout);
    });
  });

  group('pickHinge', () {
    test('ignores a fold on the window edge', () {
      expect(
        TwinResolver.pickHinge(<DisplayFeature>[verticalFold(400, 600)], const Size(400, 600)),
        isNull,
      );
    });

    test('ignores cutouts', () {
      const DisplayFeature cutout = DisplayFeature(
        bounds: Rect.fromLTWH(390, 0, 20, 20),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      );
      expect(TwinResolver.pickHinge(<DisplayFeature>[cutout], const Size(800, 600)), isNull);
    });
  });

  group('inferDeviceType', () {
    TwinHinge hinge(TwinHingeAxis axis, {DisplayFeatureType type = DisplayFeatureType.fold}) =>
        TwinHinge(
          bounds: Rect.zero,
          axis: axis,
          isSeparating: true,
          occludesContent: type == DisplayFeatureType.hinge,
          type: type,
        );

    test('a physical hinge is a dual-screen device', () {
      expect(
        TwinResolver.inferDeviceType(
          hinge(TwinHingeAxis.vertical, type: DisplayFeatureType.hinge),
          const Size(1114, 720),
          0,
        ),
        TwinDeviceType.dualScreen,
      );
    });

    test('uses the rotation when known', () {
      const Size size = Size(841, 701);
      expect(
        TwinResolver.inferDeviceType(hinge(TwinHingeAxis.vertical), size, 0),
        TwinDeviceType.foldable,
      );
      expect(
        TwinResolver.inferDeviceType(hinge(TwinHingeAxis.horizontal), size, 1),
        TwinDeviceType.foldable,
      );
      expect(
        TwinResolver.inferDeviceType(hinge(TwinHingeAxis.horizontal), const Size(411, 1006), 0),
        TwinDeviceType.flip,
      );
    });

    test('falls back to the window shape', () {
      expect(
        TwinResolver.inferDeviceType(hinge(TwinHingeAxis.horizontal), const Size(411, 1006), null),
        TwinDeviceType.flip,
      );
      expect(
        TwinResolver.inferDeviceType(hinge(TwinHingeAxis.horizontal), const Size(823, 707), null),
        TwinDeviceType.foldable,
      );
    });
  });

  group('TwinHinge.fromDisplayFeature', () {
    test('a flat fold does not separate', () {
      final TwinHinge h = TwinHinge.fromDisplayFeature(
        verticalFold(400, 600, state: DisplayFeatureState.postureFlat),
        const Size(800, 600),
      );
      expect(h.isSeparating, isFalse);
      expect(h.occludesContent, isFalse);
    });

    test('a hinge with width separates and hides content', () {
      final TwinHinge h = TwinHinge.fromDisplayFeature(
        const DisplayFeature(
          bounds: Rect.fromLTWH(540, 0, 34, 720),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
        const Size(1114, 720),
      );
      expect(h.axis, TwinHingeAxis.vertical);
      expect(h.isSeparating, isTrue);
      expect(h.occludesContent, isTrue);
      expect(h.isPhysicalHinge, isTrue);
    });
  });
}
