import 'dart:ui' show DisplayFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'twin_enums.dart';
import 'twin_hinge.dart';
import 'window_class.dart';

/// Everything this package knows about the device and how the app is shown.
///
/// Read it with `TwinScreen.of(context)`.
@immutable
class TwinScreenData {
  /// Creates screen data. Usually built by `TwinScreenScope`.
  const TwinScreenData({
    required this.deviceType,
    required this.posture,
    required this.isSpanned,
    required this.segments,
    required this.windowClass,
    required this.mode,
    required this.size,
    this.hinge,
    this.hingeAngle,
    this.textDirection = TextDirection.ltr,
    this.source = TwinDataSource.fallback,
    this.displayFeatures = const <DisplayFeature>[],
  });

  /// The kind of hardware. Stable for the session.
  final TwinDeviceType deviceType;

  /// The physical hinge state.
  final TwinPosture posture;

  /// Whether the app window crosses a fold or hinge, so it has two
  /// [segments].
  final bool isSpanned;

  /// The fold or hinge crossing the window, or null.
  final TwinHinge? hinge;

  /// The hinge angle in degrees: 0 is shut, 180 is flat.
  ///
  /// Null when the platform has no hinge sensor.
  final double? hingeAngle;

  /// The usable regions of the window in logical pixels, in start → end
  /// order for [textDirection].
  ///
  /// One rectangle when the window does not span a fold, two when it does.
  /// The area under the hinge is not part of any segment.
  final List<Rect> segments;

  /// The Material 3 size class of the window.
  final WindowClass windowClass;

  /// The combined state. See [TwinScreenMode].
  final TwinScreenMode mode;

  /// The window size in logical pixels.
  final Size size;

  /// The text direction used to order [segments].
  final TextDirection textDirection;

  /// Where the fold information came from.
  final TwinDataSource source;

  /// The display features in effect, as also seen in
  /// `MediaQuery.displayFeatures` below the scope.
  final List<DisplayFeature> displayFeatures;

  /// Whether the device has a fold or hinge.
  bool get isFoldable => deviceType.isFoldable;

  /// Whether a hinge crosses the window and splits it into two areas.
  bool get hasSeparatingHinge => hinge?.isSeparating ?? false;

  /// The leading segment (left in LTR, right in RTL, top for a horizontal
  /// hinge).
  Rect get startSegment => segments.first;

  /// The trailing segment. Equal to [startSegment] when not spanned.
  Rect get endSegment => segments.last;

  /// The segment for [side].
  Rect segmentFor(TwinPaneSide side) => side == TwinPaneSide.start ? startSegment : endSegment;

  /// This data with [segments] ordered for [direction].
  ///
  /// Only a vertical hinge changes order; top stays start for a horizontal
  /// one.
  TwinScreenData withTextDirection(TextDirection direction) {
    if (direction == textDirection) return this;
    final bool reorder = segments.length > 1 && hinge?.axis == TwinHingeAxis.vertical;
    return copyWith(
      textDirection: direction,
      segments: reorder ? segments.reversed.toList(growable: false) : segments,
    );
  }

  /// Returns a copy with the given fields replaced.
  TwinScreenData copyWith({
    TwinDeviceType? deviceType,
    TwinPosture? posture,
    bool? isSpanned,
    ValueGetter<TwinHinge?>? hinge,
    ValueGetter<double?>? hingeAngle,
    List<Rect>? segments,
    WindowClass? windowClass,
    TwinScreenMode? mode,
    Size? size,
    TextDirection? textDirection,
    TwinDataSource? source,
    List<DisplayFeature>? displayFeatures,
  }) {
    return TwinScreenData(
      deviceType: deviceType ?? this.deviceType,
      posture: posture ?? this.posture,
      isSpanned: isSpanned ?? this.isSpanned,
      hinge: hinge != null ? hinge() : this.hinge,
      hingeAngle: hingeAngle != null ? hingeAngle() : this.hingeAngle,
      segments: segments ?? this.segments,
      windowClass: windowClass ?? this.windowClass,
      mode: mode ?? this.mode,
      size: size ?? this.size,
      textDirection: textDirection ?? this.textDirection,
      source: source ?? this.source,
      displayFeatures: displayFeatures ?? this.displayFeatures,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TwinScreenData &&
      other.deviceType == deviceType &&
      other.posture == posture &&
      other.isSpanned == isSpanned &&
      other.hinge == hinge &&
      other.hingeAngle == hingeAngle &&
      listEquals(other.segments, segments) &&
      other.windowClass == windowClass &&
      other.mode == mode &&
      other.size == size &&
      other.textDirection == textDirection &&
      other.source == source &&
      listEquals(other.displayFeatures, displayFeatures);

  @override
  int get hashCode => Object.hash(
    deviceType,
    posture,
    isSpanned,
    hinge,
    hingeAngle,
    Object.hashAll(segments),
    windowClass,
    mode,
    size,
    textDirection,
    source,
    Object.hashAll(displayFeatures),
  );

  @override
  String toString() =>
      'TwinScreenData(mode: ${mode.name}, device: ${deviceType.name}, '
      'posture: ${posture.name}, spanned: $isSpanned, angle: $hingeAngle, '
      'hinge: $hinge, segments: $segments, $windowClass, size: $size, '
      'source: ${source.name})';
}
