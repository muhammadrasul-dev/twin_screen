import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/twin_enums.dart';

/// What the platform reports about the device, before it is combined with
/// the window size into `TwinScreenData`.
///
/// Also used to fake a device in tests:
///
/// ```dart
/// TwinScreenScope(
///   platformOverride: TwinPlatformState(
///     deviceType: TwinDeviceType.foldable,
///     posture: TwinPosture.halfOpened,
///     displayFeatures: [
///       DisplayFeature(
///         bounds: Rect.fromLTWH(345, 0, 0, 829),
///         type: DisplayFeatureType.fold,
///         state: DisplayFeatureState.postureHalfOpened,
///       ),
///     ],
///   ),
///   child: MyApp(),
/// )
/// ```
@immutable
class TwinPlatformState {
  /// Creates a platform state.
  const TwinPlatformState({
    this.deviceType = TwinDeviceType.unknown,
    this.posture = TwinPosture.unknown,
    this.hingeAngle,
    this.displayFeatures = const <DisplayFeature>[],
    this.rotationQuarterTurns,
    this.source = TwinDataSource.fallback,
  });

  /// Parses the map sent by the native side over the platform channel.
  factory TwinPlatformState.fromMap(Map<Object?, Object?> map) {
    final Object? features = map['features'];
    return TwinPlatformState(
      deviceType: _enumByName(TwinDeviceType.values, map['deviceType'], TwinDeviceType.unknown),
      posture: _enumByName(TwinPosture.values, map['posture'], TwinPosture.unknown),
      hingeAngle: (map['hingeAngle'] as num?)?.toDouble(),
      rotationQuarterTurns: (map['rotation'] as num?)?.toInt(),
      displayFeatures: features is List<Object?>
          ? features
                .whereType<Map<Object?, Object?>>()
                .map(_featureFromMap)
                .whereType<DisplayFeature>()
                .toList(growable: false)
          : const <DisplayFeature>[],
      source: TwinDataSource.plugin,
    );
  }

  /// The state used where no platform code runs: an ordinary device.
  static const TwinPlatformState fallback = TwinPlatformState(deviceType: TwinDeviceType.standard);

  /// The hardware type as far as the platform can tell.
  ///
  /// Android and iOS know this from the hinge sensor. Web reports
  /// [TwinDeviceType.unknown].
  final TwinDeviceType deviceType;

  /// The hinge posture, from the hinge sensor or the web posture API.
  ///
  /// When the window spans a fold, the fold's own state takes priority.
  final TwinPosture posture;

  /// The hinge angle in degrees, or null without a sensor.
  final double? hingeAngle;

  /// Display features the platform reports but Flutter does not, in logical
  /// pixels in the window's coordinate space.
  ///
  /// `TwinScreenScope` adds these to `MediaQuery.displayFeatures` unless
  /// Flutter already reports a feature of the same kind.
  final List<DisplayFeature> displayFeatures;

  /// How far the display is rotated from its natural orientation, in
  /// clockwise quarter turns. Used to tell book foldables from flip phones.
  final int? rotationQuarterTurns;

  /// Where this state came from.
  final TwinDataSource source;

  /// Returns a copy with the given fields replaced.
  TwinPlatformState copyWith({
    TwinDeviceType? deviceType,
    TwinPosture? posture,
    ValueGetter<double?>? hingeAngle,
    List<DisplayFeature>? displayFeatures,
    ValueGetter<int?>? rotationQuarterTurns,
    TwinDataSource? source,
  }) {
    return TwinPlatformState(
      deviceType: deviceType ?? this.deviceType,
      posture: posture ?? this.posture,
      hingeAngle: hingeAngle != null ? hingeAngle() : this.hingeAngle,
      displayFeatures: displayFeatures ?? this.displayFeatures,
      rotationQuarterTurns: rotationQuarterTurns != null
          ? rotationQuarterTurns()
          : this.rotationQuarterTurns,
      source: source ?? this.source,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TwinPlatformState &&
      other.deviceType == deviceType &&
      other.posture == posture &&
      other.hingeAngle == hingeAngle &&
      listEquals(other.displayFeatures, displayFeatures) &&
      other.rotationQuarterTurns == rotationQuarterTurns &&
      other.source == source;

  @override
  int get hashCode => Object.hash(
    deviceType,
    posture,
    hingeAngle,
    Object.hashAll(displayFeatures),
    rotationQuarterTurns,
    source,
  );

  @override
  String toString() =>
      'TwinPlatformState(${deviceType.name}, ${posture.name}, angle: $hingeAngle, '
      'features: $displayFeatures, rotation: $rotationQuarterTurns, ${source.name})';
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T orElse) {
  for (final T value in values) {
    if (value.name == name) return value;
  }
  return orElse;
}

DisplayFeature? _featureFromMap(Map<Object?, Object?> map) {
  final num? left = map['left'] as num?;
  final num? top = map['top'] as num?;
  final num? right = map['right'] as num?;
  final num? bottom = map['bottom'] as num?;
  if (left == null || top == null || right == null || bottom == null) return null;
  return DisplayFeature(
    bounds: Rect.fromLTRB(left.toDouble(), top.toDouble(), right.toDouble(), bottom.toDouble()),
    type: switch (map['type']) {
      'hinge' => DisplayFeatureType.hinge,
      'cutout' => DisplayFeatureType.cutout,
      'fold' => DisplayFeatureType.fold,
      _ => DisplayFeatureType.unknown,
    },
    state: switch (map['state']) {
      'flat' => DisplayFeatureState.postureFlat,
      'halfOpened' => DisplayFeatureState.postureHalfOpened,
      _ => DisplayFeatureState.unknown,
    },
  );
}
