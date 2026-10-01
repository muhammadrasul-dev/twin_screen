import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'twin_enums.dart';

/// A fold or hinge that crosses the app window.
@immutable
class TwinHinge {
  /// Creates a hinge description.
  const TwinHinge({
    required this.bounds,
    required this.axis,
    required this.isSeparating,
    required this.occludesContent,
    this.type = DisplayFeatureType.fold,
    this.state = DisplayFeatureState.unknown,
  });

  /// Describes a Flutter [DisplayFeature] of type fold or hinge.
  ///
  /// [windowSize] is used to pick the axis of a feature with no area. Pass
  /// [halfOpened] when the hinge sensor knows better than the feature's own
  /// state (some Android builds keep reporting a flat fold while the device
  /// is half-open).
  ///
  /// The rules match Flutter's `DisplayFeatureSubScreen` and Jetpack
  /// WindowManager: a feature separates the window when it hides content or
  /// when the device is half-opened. It hides content when it is at least
  /// [minOccludingExtent] wide; thinner features, such as the one-pixel fold
  /// some emulators report as a hinge, are treated as a seam.
  factory TwinHinge.fromDisplayFeature(
    DisplayFeature feature,
    Size windowSize, {
    bool? halfOpened,
  }) {
    final Rect bounds = feature.bounds;
    final bool occludes = bounds.shortestSide >= minOccludingExtent;
    return TwinHinge(
      bounds: bounds,
      axis: axisOf(bounds, windowSize),
      isSeparating:
          occludes || (halfOpened ?? feature.state == DisplayFeatureState.postureHalfOpened),
      occludesContent: occludes,
      type: feature.type,
      state: feature.state,
    );
  }

  /// The smallest width, in logical pixels, at which a hinge hides content.
  static const double minOccludingExtent = 1;

  /// The hinge's rectangle in logical pixels, in the window's coordinate
  /// space. It can have zero width or height.
  final Rect bounds;

  /// Whether the hinge runs vertically or horizontally.
  final TwinHingeAxis axis;

  /// Whether the hinge splits the window into two areas that should hold
  /// separate content.
  ///
  /// True for physical hinges and for folds on a half-opened device.
  final bool isSeparating;

  /// Whether content under [bounds] cannot be seen.
  ///
  /// True for physical hinges that have a width, like on Surface Duo.
  final bool occludesContent;

  /// The Flutter display feature type: [DisplayFeatureType.fold] or
  /// [DisplayFeatureType.hinge].
  final DisplayFeatureType type;

  /// The Flutter display feature state.
  final DisplayFeatureState state;

  /// Whether this is a physical hinge between two panels rather than a fold
  /// in a flexible screen: reported as a hinge, and wide enough to hide
  /// content.
  bool get isPhysicalHinge => type == DisplayFeatureType.hinge && occludesContent;

  /// Works out the axis of a feature with the given [bounds].
  static TwinHingeAxis axisOf(Rect bounds, Size windowSize) {
    if (bounds.height > bounds.width) return TwinHingeAxis.vertical;
    if (bounds.width > bounds.height) return TwinHingeAxis.horizontal;
    // A point-sized feature: pick the axis that crosses the window.
    return bounds.top <= 0 && bounds.bottom >= windowSize.height
        ? TwinHingeAxis.vertical
        : TwinHingeAxis.horizontal;
  }

  @override
  bool operator ==(Object other) =>
      other is TwinHinge &&
      other.bounds == bounds &&
      other.axis == axis &&
      other.isSeparating == isSeparating &&
      other.occludesContent == occludesContent &&
      other.type == type &&
      other.state == state;

  @override
  int get hashCode => Object.hash(bounds, axis, isSeparating, occludesContent, type, state);

  @override
  String toString() =>
      'TwinHinge(${axis.name}, $bounds, separating: $isSeparating, '
      'occludes: $occludesContent, ${type.name}, ${state.name})';
}
