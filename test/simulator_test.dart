import 'dart:ui' show DisplayFeature;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twin_screen/twin_screen.dart';

TwinScreenData resolveScreen(TwinSimulatedScreen screen) => TwinResolver.resolve(
  size: screen.size,
  flutterFeatures: const <DisplayFeature>[],
  platform: screen.platform.copyWith(displayFeatures: screen.displayFeatures),
);

void main() {
  test('every preset, posture, orientation and span gives the expected mode', () {
    for (final TwinDevicePreset preset in TwinDevicePreset.all) {
      for (final Orientation orientation in Orientation.values) {
        for (final TwinPosture posture in <TwinPosture>[
          TwinPosture.closed,
          TwinPosture.halfOpened,
          TwinPosture.flat,
        ]) {
          for (final TwinSimulatedSpan span in TwinSimulatedSpan.values) {
            final TwinSimulatedScreen screen = TwinSimulatedScreen.resolve(
              preset: preset,
              posture: posture,
              hingeAngle: TwinSimulatorController.defaultAngleFor(posture),
              orientation: orientation,
              span: span,
            );
            final TwinScreenData data = resolveScreen(screen);
            final String label = '${preset.name} $orientation $posture $span';

            expect(data.deviceType, preset.deviceType, reason: label);
            if (posture == TwinPosture.closed) {
              expect(data.mode, TwinScreenMode.cover, reason: label);
              continue;
            }
            if (span != TwinSimulatedSpan.both) {
              expect(data.mode, TwinScreenMode.singlePane, reason: label);
              continue;
            }
            final bool natural =
                (preset.innerSize.width > preset.innerSize.height) ==
                (orientation == Orientation.landscape);
            final TwinHingeAxis axis = natural
                ? preset.innerHingeAxis
                : preset.innerHingeAxis.flipped;
            expect(data.hinge?.axis, axis, reason: label);
            expect(data.segments, hasLength(2), reason: label);
            expect(
              data.mode,
              posture == TwinPosture.flat
                  ? TwinScreenMode.dualPane
                  : (axis == TwinHingeAxis.vertical
                        ? TwinScreenMode.book
                        : TwinScreenMode.tabletop),
              reason: label,
            );
          }
        }
      }
    }
  });

  test('iPhone Duo matches the iOS 27.1 simulator geometry', () {
    const TwinDevicePreset duo = TwinDevicePreset.iPhoneDuo;
    expect(duo.platform, TargetPlatform.iOS);
    final TwinSimulatedScreen portrait = TwinSimulatedScreen.resolve(
      preset: duo,
      posture: TwinPosture.halfOpened,
      hingeAngle: 110,
      orientation: Orientation.portrait,
      span: TwinSimulatedSpan.both,
    );
    final TwinSimulatedScreen landscape = TwinSimulatedScreen.resolve(
      preset: duo,
      posture: TwinPosture.halfOpened,
      hingeAngle: 110,
      orientation: Orientation.landscape,
      span: TwinSimulatedSpan.both,
    );
    // CoreSimulator profile: cover 1398 × 2034 px, inner 2007 × 2853 px, @3x.
    // On the cover screen the app window is 386 pt wide (80 pt status column).
    expect(duo.coverSize, const Size(386, 678));
    expect(portrait.size, const Size(669, 951));
    expect(landscape.size, const Size(951, 669));
    // The inner screen folds like a book in landscape; held in portrait the
    // fold runs across.
    expect(resolveScreen(landscape).mode, TwinScreenMode.book);
    expect(resolveScreen(portrait).mode, TwinScreenMode.tabletop);
  });

  test('Surface Duo hinge hides content between two panels', () {
    final TwinSimulatedScreen screen = TwinSimulatedScreen.resolve(
      preset: TwinDevicePreset.surfaceDuo,
      posture: TwinPosture.flat,
      hingeAngle: 180,
      orientation: Orientation.landscape,
      span: TwinSimulatedSpan.both,
    );
    final TwinScreenData data = resolveScreen(screen);
    expect(data.hinge!.occludesContent, isTrue);
    expect(data.segments, const <Rect>[
      Rect.fromLTRB(0, 0, 540, 720),
      Rect.fromLTRB(574, 0, 1114, 720),
    ]);
  });

  group('TwinSimulatorController', () {
    test('angle and posture follow each other', () {
      final TwinSimulatorController c = TwinSimulatorController(enabled: true);
      c.hingeAngle = 10;
      expect(c.posture, TwinPosture.closed);
      c.hingeAngle = 90;
      expect(c.posture, TwinPosture.halfOpened);
      c.hingeAngle = 170;
      expect(c.posture, TwinPosture.flat);
      c.posture = TwinPosture.halfOpened;
      expect(c.hingeAngle, 110);
    });

    test('a device without a cover screen cannot close', () {
      final TwinSimulatorController c = TwinSimulatorController(
        enabled: true,
        posture: TwinPosture.closed,
      );
      c.preset = TwinDevicePreset.surfaceDuo;
      expect(c.posture, TwinPosture.flat);
      c.hingeAngle = 0;
      expect(c.posture, TwinPosture.halfOpened);
    });

    test('simulate turns it on and notifies once', () {
      final TwinSimulatorController c = TwinSimulatorController();
      int notified = 0;
      c.addListener(() => notified++);
      c.simulate(preset: TwinDevicePreset.galaxyZFlip, posture: TwinPosture.halfOpened);
      expect(c.enabled, isTrue);
      expect(c.preset, TwinDevicePreset.galaxyZFlip);
      expect(notified, 1);
      c.stop();
      expect(c.enabled, isFalse);
    });
  });
}
