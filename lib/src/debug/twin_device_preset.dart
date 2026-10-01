import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/twin_enums.dart';

/// A device shape for the fold simulator in `TwinDebugOverlay`.
///
/// Sizes are logical pixels (Android dp, iOS points) taken from public
/// specifications, rounded. They are close enough to test layouts, not exact.
@immutable
class TwinDevicePreset {
  /// Creates a preset.
  const TwinDevicePreset({
    required this.name,
    required this.deviceType,
    required this.innerSize,
    required this.innerHingeAxis,
    this.coverSize,
    this.hingeWidth = 0,
    this.statusBarHeight = 24,
    this.bottomInset = 16,
    this.platform = TargetPlatform.android,
  });

  /// iPhone Duo (iOS 27.1): a 951 × 669 pt inner screen that folds like a
  /// book in landscape, and a 466 × 678 pt cover screen whose right 80 pt
  /// hold the camera and status bar, so apps get a 386 × 678 pt window.
  ///
  /// Sizes come from the iOS 27.1 simulator.
  static const TwinDevicePreset iPhoneDuo = TwinDevicePreset(
    name: 'iPhone Duo',
    deviceType: TwinDeviceType.foldable,
    coverSize: Size(386, 678),
    innerSize: Size(951, 669),
    innerHingeAxis: TwinHingeAxis.vertical,
    statusBarHeight: 44,
    bottomInset: 20,
    platform: TargetPlatform.iOS,
  );

  /// Samsung Galaxy Z Fold: tall cover screen, near-square inner screen.
  static const TwinDevicePreset galaxyZFold = TwinDevicePreset(
    name: 'Galaxy Z Fold',
    deviceType: TwinDeviceType.foldable,
    coverSize: Size(369, 905),
    innerSize: Size(707, 823),
    innerHingeAxis: TwinHingeAxis.vertical,
  );

  /// Samsung Galaxy Z Flip: small square cover screen, tall inner screen with
  /// a horizontal fold.
  static const TwinDevicePreset galaxyZFlip = TwinDevicePreset(
    name: 'Galaxy Z Flip',
    deviceType: TwinDeviceType.flip,
    coverSize: Size(360, 374),
    innerSize: Size(411, 1006),
    innerHingeAxis: TwinHingeAxis.horizontal,
  );

  /// Google Pixel Fold: its inner screen is landscape in its natural
  /// orientation.
  static const TwinDevicePreset pixelFold = TwinDevicePreset(
    name: 'Pixel Fold',
    deviceType: TwinDeviceType.foldable,
    coverSize: Size(411, 797),
    innerSize: Size(841, 701),
    innerHingeAxis: TwinHingeAxis.vertical,
  );

  /// Microsoft Surface Duo: two 540 × 720 dp panels with a 34 dp hinge that
  /// hides content. No cover screen.
  static const TwinDevicePreset surfaceDuo = TwinDevicePreset(
    name: 'Surface Duo',
    deviceType: TwinDeviceType.dualScreen,
    innerSize: Size(1114, 720),
    innerHingeAxis: TwinHingeAxis.vertical,
    hingeWidth: 34,
  );

  /// Xiaomi Mix Flip: large cover screen, tall inner screen with a horizontal
  /// fold.
  static const TwinDevicePreset xiaomiMixFlip = TwinDevicePreset(
    name: 'Xiaomi Mix Flip',
    deviceType: TwinDeviceType.flip,
    coverSize: Size(439, 506),
    innerSize: Size(445, 1059),
    innerHingeAxis: TwinHingeAxis.horizontal,
  );

  /// All built-in presets.
  static const List<TwinDevicePreset> all = <TwinDevicePreset>[
    iPhoneDuo,
    galaxyZFold,
    galaxyZFlip,
    pixelFold,
    surfaceDuo,
    xiaomiMixFlip,
  ];

  /// The name shown in the simulator.
  final String name;

  /// The hardware type reported while simulating.
  final TwinDeviceType deviceType;

  /// The app window on the outer screen in its natural orientation, or null
  /// when the device has no outer screen (Surface Duo).
  final Size? coverSize;

  /// The unfolded screen in its natural orientation. For dual-screen devices,
  /// both panels plus the hinge.
  final Size innerSize;

  /// The fold's axis on the unfolded screen in its natural orientation.
  final TwinHingeAxis innerHingeAxis;

  /// The width of a physical hinge that hides content. Zero for folds.
  final double hingeWidth;

  /// The top safe-area inset.
  final double statusBarHeight;

  /// The bottom safe-area inset.
  final double bottomInset;

  /// The platform this device runs, shown in the info panel.
  final TargetPlatform platform;

  /// Whether the device has an outer screen.
  bool get hasCover => coverSize != null;

  @override
  bool operator ==(Object other) =>
      other is TwinDevicePreset &&
      other.name == name &&
      other.deviceType == deviceType &&
      other.coverSize == coverSize &&
      other.innerSize == innerSize &&
      other.innerHingeAxis == innerHingeAxis &&
      other.hingeWidth == hingeWidth &&
      other.statusBarHeight == statusBarHeight &&
      other.bottomInset == bottomInset &&
      other.platform == platform;

  @override
  int get hashCode => Object.hash(
    name,
    deviceType,
    coverSize,
    innerSize,
    innerHingeAxis,
    hingeWidth,
    statusBarHeight,
    bottomInset,
    platform,
  );

  @override
  String toString() => 'TwinDevicePreset($name)';
}
