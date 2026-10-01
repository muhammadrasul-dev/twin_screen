import 'package:flutter/widgets.dart';

/// The kind of hardware the app is running on.
///
/// This is a hardware fact and stays the same for the whole session, no
/// matter whether the device is currently open, closed or folded.
enum TwinDeviceType {
  /// An ordinary phone, tablet, desktop or browser without a fold.
  standard,

  /// A book-style foldable whose fold is vertical in its natural orientation,
  /// for example Galaxy Z Fold, Pixel Fold, Honor Magic V or iPhone Duo.
  foldable,

  /// A clamshell flip phone whose fold is horizontal in its natural
  /// orientation, for example Galaxy Z Flip, Xiaomi Mix Flip or Moto Razr.
  flip,

  /// Two physical panels joined by a hinge, for example Surface Duo.
  dualScreen,

  /// The platform cannot tell. Web browsers report this until they expose a
  /// fold through the Viewport Segments API.
  unknown;

  /// Whether the device has a fold or a hinge.
  bool get isFoldable => this == foldable || this == flip || this == dualScreen;
}

/// The physical state of the hinge.
enum TwinPosture {
  /// The device is folded shut. On foldables with an outer display the app
  /// runs on the cover screen.
  closed,

  /// The device is partly open, like a laptop or a half-open book.
  halfOpened,

  /// The device is fully open and flat.
  flat,

  /// The posture is not known, for example on devices without a hinge sensor.
  unknown,
}

/// One combined answer to "how is the app being shown right now?".
///
/// Derived from [TwinDeviceType], [TwinPosture], whether the window spans the
/// fold, and the fold's axis.
enum TwinScreenMode {
  /// An ordinary device without a fold.
  standard,

  /// A foldable that is closed, with the app on the outer (cover) screen.
  cover,

  /// The device is open, but the app only occupies one side of the fold, for
  /// example in split-screen or on one panel of a dual-screen device.
  singlePane,

  /// The app spans both sides of a flat, fully open device.
  dualPane,

  /// The app spans a half-opened device with a vertical fold, held like a
  /// book.
  book,

  /// The app spans a half-opened device with a horizontal fold, standing like
  /// a laptop on a table.
  tabletop;

  /// Whether the app window crosses the fold in this mode.
  bool get isSpanned => this == dualPane || this == book || this == tabletop;
}

/// The direction in which a fold or hinge runs.
enum TwinHingeAxis {
  /// The hinge runs from top to bottom, splitting the window into a left and
  /// a right half.
  vertical,

  /// The hinge runs from left to right, splitting the window into a top and a
  /// bottom half.
  horizontal;

  /// The axis along which the two halves are laid out.
  ///
  /// A [vertical] hinge puts the halves side by side ([Axis.horizontal]).
  Axis get paneAxis => this == vertical ? Axis.horizontal : Axis.vertical;

  /// The other axis.
  TwinHingeAxis get flipped => this == vertical ? horizontal : vertical;
}

/// Where the fold information came from.
enum TwinDataSource {
  /// Flutter itself reported the fold through `MediaQuery.displayFeatures`
  /// (Android today).
  flutter,

  /// This package read the fold from the platform (iOS or web) and injected
  /// it into `MediaQuery.displayFeatures`.
  plugin,

  /// The fold is simulated by `TwinDebugOverlay` or a test override.
  simulator,

  /// No fold information is available on this platform.
  fallback,
}

/// One of the two halves of a split layout.
///
/// [start] is the left half in left-to-right locales, the right half in
/// right-to-left locales, and the top half when the hinge is horizontal.
enum TwinPaneSide {
  /// The leading half.
  start,

  /// The trailing half.
  end;

  /// The other side.
  TwinPaneSide get opposite => this == start ? end : start;
}
