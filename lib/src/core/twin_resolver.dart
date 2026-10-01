import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/painting.dart';

import '../models/twin_enums.dart';
import '../models/twin_hinge.dart';
import '../models/twin_screen_data.dart';
import '../models/window_class.dart';
import '../platform/twin_platform_state.dart';

/// Pure functions that turn raw platform input into [TwinScreenData].
///
/// Kept free of widgets so every rule can be unit tested.
abstract final class TwinResolver {
  /// Open flip phones are much longer than they are wide (about 22:9); book
  /// foldables open close to square. Used when the display rotation is not
  /// known.
  static const double flipAspectRatio = 1.8;

  /// Combines the window, Flutter's display features and the platform report
  /// into [TwinScreenData], with segments ordered for [textDirection].
  static TwinScreenData resolve({
    required Size size,
    required List<DisplayFeature> flutterFeatures,
    required TwinPlatformState platform,
    WindowClassBreakpoints breakpoints = WindowClassBreakpoints.material3,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final List<DisplayFeature> features = mergeFeatures(flutterFeatures, platform.displayFeatures);
    final DisplayFeature? feature = pickHinge(features, size);
    final TwinPosture posture = resolvePosture(platform.posture, feature?.state);
    final TwinHinge? hinge = feature == null
        ? null
        : TwinHinge.fromDisplayFeature(
            feature,
            size,
            halfOpened: posture == TwinPosture.halfOpened,
          );
    final WindowClass windowClass = breakpoints.classOf(size);

    // A fold crossing the window shows the hardware type better than the
    // platform's guess, as long as its axis can be put in the display's
    // natural orientation (Android sends the rotation). A dual-screen report
    // (Surface Duo, by model) is kept.
    TwinDeviceType deviceType = platform.deviceType;
    if (hinge != null &&
        deviceType != TwinDeviceType.dualScreen &&
        (!deviceType.isFoldable || platform.rotationQuarterTurns != null)) {
      deviceType = inferDeviceType(hinge, size, platform.rotationQuarterTurns);
    }
    final bool isSpanned = hinge != null;

    final TwinDataSource source;
    if (platform.source == TwinDataSource.simulator) {
      source = TwinDataSource.simulator;
    } else if (feature != null && flutterFeatures.contains(feature)) {
      source = TwinDataSource.flutter;
    } else {
      source = platform.source;
    }

    return TwinScreenData(
      deviceType: deviceType,
      posture: posture,
      isSpanned: isSpanned,
      hinge: hinge,
      hingeAngle: platform.hingeAngle,
      segments: segmentsFor(size, hinge),
      windowClass: windowClass,
      mode: resolveMode(
        deviceType: deviceType,
        posture: posture,
        isSpanned: isSpanned,
        hingeAxis: hinge?.axis,
        widthClass: windowClass.width,
      ),
      size: size,
      source: source,
      displayFeatures: features,
    ).withTextDirection(textDirection);
  }

  /// Works out the combined [TwinScreenMode].
  ///
  /// | device    | posture          | spanned | axis       | mode        |
  /// |-----------|------------------|---------|------------|-------------|
  /// | standard  | any              | no      | –          | standard    |
  /// | foldable  | closed           | no      | –          | cover       |
  /// | foldable  | flat, halfOpened | no      | –          | singlePane  |
  /// | foldable  | unknown          | no      | –          | compact width → cover, else singlePane |
  /// | any       | halfOpened       | yes     | vertical   | book        |
  /// | any       | halfOpened       | yes     | horizontal | tabletop    |
  /// | any       | other            | yes     | any        | dualPane    |
  static TwinScreenMode resolveMode({
    required TwinDeviceType deviceType,
    required TwinPosture posture,
    required bool isSpanned,
    required WindowWidthClass widthClass,
    TwinHingeAxis? hingeAxis,
  }) {
    if (isSpanned) {
      if (posture == TwinPosture.halfOpened) {
        return hingeAxis == TwinHingeAxis.horizontal
            ? TwinScreenMode.tabletop
            : TwinScreenMode.book;
      }
      return TwinScreenMode.dualPane;
    }
    if (!deviceType.isFoldable) return TwinScreenMode.standard;
    return switch (posture) {
      TwinPosture.closed => TwinScreenMode.cover,
      TwinPosture.halfOpened || TwinPosture.flat => TwinScreenMode.singlePane,
      TwinPosture.unknown =>
        widthClass == WindowWidthClass.compact ? TwinScreenMode.cover : TwinScreenMode.singlePane,
    };
  }

  /// Guesses the hardware type from a fold that crosses the window.
  ///
  /// A physical hinge means two panels. For a fold, its axis in the display's
  /// natural orientation decides: vertical is a book foldable, horizontal a
  /// flip phone. Without the rotation, the window's shape decides instead.
  static TwinDeviceType inferDeviceType(TwinHinge hinge, Size size, int? rotationQuarterTurns) {
    if (hinge.isPhysicalHinge) return TwinDeviceType.dualScreen;
    if (rotationQuarterTurns != null) {
      final TwinHingeAxis naturalAxis = rotationQuarterTurns.isOdd
          ? hinge.axis.flipped
          : hinge.axis;
      return naturalAxis == TwinHingeAxis.vertical ? TwinDeviceType.foldable : TwinDeviceType.flip;
    }
    final double ratio = size.longestSide / size.shortestSide;
    return ratio >= flipAspectRatio ? TwinDeviceType.flip : TwinDeviceType.foldable;
  }

  /// Adds the plugin's features to Flutter's without duplicating them.
  ///
  /// If Flutter already reports a fold or hinge, the plugin's folds are
  /// dropped; the same goes for cutouts.
  static List<DisplayFeature> mergeFeatures(
    List<DisplayFeature> flutterFeatures,
    List<DisplayFeature> pluginFeatures,
  ) {
    if (pluginFeatures.isEmpty) return flutterFeatures;
    final bool flutterHasFold = flutterFeatures.any(isFoldOrHinge);
    final bool flutterHasCutout = flutterFeatures.any(
      (DisplayFeature f) => f.type == DisplayFeatureType.cutout,
    );
    final List<DisplayFeature> extra = <DisplayFeature>[
      for (final DisplayFeature f in pluginFeatures)
        if (isFoldOrHinge(f) ? !flutterHasFold : !flutterHasCutout) f,
    ];
    if (extra.isEmpty) return flutterFeatures;
    return List<DisplayFeature>.unmodifiable(<DisplayFeature>[...flutterFeatures, ...extra]);
  }

  /// Whether [feature] is a fold or a hinge (not a cutout).
  static bool isFoldOrHinge(DisplayFeature feature) =>
      feature.type == DisplayFeatureType.fold || feature.type == DisplayFeatureType.hinge;

  /// The fold or hinge that crosses the window, closest to its centre.
  ///
  /// Features that only touch an edge of the window, or lie outside it, are
  /// ignored: a window that ends at the fold does not span it.
  static DisplayFeature? pickHinge(List<DisplayFeature> features, Size size) {
    DisplayFeature? best;
    double bestDistance = double.infinity;
    final Offset centre = size.center(Offset.zero);
    for (final DisplayFeature feature in features) {
      if (!isFoldOrHinge(feature) || !_crossesWindow(feature.bounds, size)) continue;
      final double distance = (feature.bounds.center - centre).distanceSquared;
      if (distance < bestDistance) {
        best = feature;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// The usable regions of a window of [size], in physical order (left to
  /// right, or top to bottom).
  static List<Rect> segmentsFor(Size size, TwinHinge? hinge) {
    final Rect window = Offset.zero & size;
    if (hinge == null) return List<Rect>.unmodifiable(<Rect>[window]);
    final Rect b = hinge.bounds;
    return List<Rect>.unmodifiable(switch (hinge.axis) {
      TwinHingeAxis.vertical => <Rect>[
        Rect.fromLTRB(0, 0, b.left.clamp(0, size.width), size.height),
        Rect.fromLTRB(b.right.clamp(0, size.width), 0, size.width, size.height),
      ],
      TwinHingeAxis.horizontal => <Rect>[
        Rect.fromLTRB(0, 0, size.width, b.top.clamp(0, size.height)),
        Rect.fromLTRB(0, b.bottom.clamp(0, size.height), size.width, size.height),
      ],
    });
  }

  static bool _crossesWindow(Rect b, Size size) {
    final bool overlapsVertically = b.top < size.height && b.bottom > 0;
    final bool overlapsHorizontally = b.left < size.width && b.right > 0;
    return switch (TwinHinge.axisOf(b, size)) {
      TwinHingeAxis.vertical => overlapsVertically && b.left > 0 && b.right < size.width,
      TwinHingeAxis.horizontal => overlapsHorizontally && b.top > 0 && b.bottom < size.height,
    };
  }

  /// Combines the posture the platform reports (from the hinge sensor) with
  /// the state of the fold crossing the window, if any.
  ///
  /// A half-opened fold wins. A flat fold yields to a sensor that reads
  /// half-open: some Android builds keep reporting a flat fold after the
  /// device bends. A window cannot span a closed device, so a stale "closed"
  /// is dropped while spanned.
  static TwinPosture resolvePosture(TwinPosture reported, DisplayFeatureState? foldState) {
    if (foldState == null) return reported;
    return switch (foldState) {
      DisplayFeatureState.postureHalfOpened => TwinPosture.halfOpened,
      DisplayFeatureState.postureFlat =>
        reported == TwinPosture.halfOpened ? TwinPosture.halfOpened : TwinPosture.flat,
      // A wildcard, not `unknown`: web's dart:ui also has `postureFlipped`.
      _ => reported == TwinPosture.closed ? TwinPosture.unknown : reported,
    };
  }
}
