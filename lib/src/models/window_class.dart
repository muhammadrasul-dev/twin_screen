import 'package:flutter/widgets.dart';

import '../widgets/twin_screen_scope.dart';
import 'twin_screen_data.dart';

/// Material 3 window width classes.
///
/// Values are ordered, so they can be compared with `<`, `>=` and friends:
///
/// ```dart
/// if (WindowClass.of(context).width >= WindowWidthClass.medium) { ... }
/// ```
enum WindowWidthClass {
  /// Narrower than 600 logical pixels by default. Most phones in portrait.
  compact,

  /// 600 to 839 logical pixels by default. Unfolded book foldables in
  /// portrait, small tablets.
  medium,

  /// 840 logical pixels or wider by default. Tablets in landscape, desktop.
  expanded;

  /// Whether this class is narrower than [other].
  bool operator <(WindowWidthClass other) => index < other.index;

  /// Whether this class is narrower than or equal to [other].
  bool operator <=(WindowWidthClass other) => index <= other.index;

  /// Whether this class is wider than [other].
  bool operator >(WindowWidthClass other) => index > other.index;

  /// Whether this class is wider than or equal to [other].
  bool operator >=(WindowWidthClass other) => index >= other.index;
}

/// Material 3 window height classes.
///
/// Values are ordered and can be compared like [WindowWidthClass].
enum WindowHeightClass {
  /// Shorter than 480 logical pixels by default. Phones in landscape.
  compact,

  /// 480 to 899 logical pixels by default.
  medium,

  /// 900 logical pixels or taller by default.
  expanded;

  /// Whether this class is shorter than [other].
  bool operator <(WindowHeightClass other) => index < other.index;

  /// Whether this class is shorter than or equal to [other].
  bool operator <=(WindowHeightClass other) => index <= other.index;

  /// Whether this class is taller than [other].
  bool operator >(WindowHeightClass other) => index > other.index;

  /// Whether this class is taller than or equal to [other].
  bool operator >=(WindowHeightClass other) => index >= other.index;
}

/// The breakpoints that turn a window size into a [WindowClass].
///
/// Defaults follow Material 3. Pass custom values to `TwinScreenScope` to
/// change them for the whole app.
@immutable
class WindowClassBreakpoints {
  /// Creates breakpoints. Each value is the smallest size, in logical pixels,
  /// that belongs to that class.
  const WindowClassBreakpoints({
    this.mediumWidth = 600,
    this.expandedWidth = 840,
    this.mediumHeight = 480,
    this.expandedHeight = 900,
  }) : assert(mediumWidth > 0 && expandedWidth > mediumWidth),
       assert(mediumHeight > 0 && expandedHeight > mediumHeight);

  /// The Material 3 breakpoints: 600 / 840 wide and 480 / 900 tall.
  static const WindowClassBreakpoints material3 = WindowClassBreakpoints();

  /// The smallest width that counts as [WindowWidthClass.medium].
  final double mediumWidth;

  /// The smallest width that counts as [WindowWidthClass.expanded].
  final double expandedWidth;

  /// The smallest height that counts as [WindowHeightClass.medium].
  final double mediumHeight;

  /// The smallest height that counts as [WindowHeightClass.expanded].
  final double expandedHeight;

  /// The width class for a window [width] wide.
  WindowWidthClass widthClassOf(double width) {
    if (width >= expandedWidth) return WindowWidthClass.expanded;
    if (width >= mediumWidth) return WindowWidthClass.medium;
    return WindowWidthClass.compact;
  }

  /// The height class for a window [height] tall.
  WindowHeightClass heightClassOf(double height) {
    if (height >= expandedHeight) return WindowHeightClass.expanded;
    if (height >= mediumHeight) return WindowHeightClass.medium;
    return WindowHeightClass.compact;
  }

  /// The window class for a window of [size].
  WindowClass classOf(Size size) =>
      WindowClass(width: widthClassOf(size.width), height: heightClassOf(size.height));

  @override
  bool operator ==(Object other) =>
      other is WindowClassBreakpoints &&
      other.mediumWidth == mediumWidth &&
      other.expandedWidth == expandedWidth &&
      other.mediumHeight == mediumHeight &&
      other.expandedHeight == expandedHeight;

  @override
  int get hashCode => Object.hash(mediumWidth, expandedWidth, mediumHeight, expandedHeight);

  @override
  String toString() =>
      'WindowClassBreakpoints(width: $mediumWidth / $expandedWidth, '
      'height: $mediumHeight / $expandedHeight)';
}

/// The Material 3 size class of the app window: a width class and a height
/// class.
///
/// Read it with [WindowClass.of], or build different layouts per class with
/// `WindowClassBuilder`.
@immutable
class WindowClass {
  /// Creates a window class.
  const WindowClass({required this.width, required this.height});

  /// The window class for [size] using [breakpoints].
  factory WindowClass.fromSize(
    Size size, {
    WindowClassBreakpoints breakpoints = WindowClassBreakpoints.material3,
  }) => breakpoints.classOf(size);

  /// The width class.
  final WindowWidthClass width;

  /// The height class.
  final WindowHeightClass height;

  /// The window class of the app window around [context].
  ///
  /// Uses the breakpoints of the nearest `TwinScreenScope`. Without a scope it
  /// falls back to `MediaQuery` and the Material 3 breakpoints. The widget
  /// rebuilds only when the class changes, not on every resize.
  static WindowClass of(BuildContext context) {
    final TwinScreenData? scoped = TwinScreen.maybeOf(context, TwinAspect.windowClass);
    if (scoped != null) return scoped.windowClass;
    return WindowClassBreakpoints.material3.classOf(MediaQuery.sizeOf(context));
  }

  /// Whether the width class is [WindowWidthClass.compact].
  bool get isCompact => width == WindowWidthClass.compact;

  /// Whether the width class is [WindowWidthClass.medium].
  bool get isMedium => width == WindowWidthClass.medium;

  /// Whether the width class is [WindowWidthClass.expanded].
  bool get isExpanded => width == WindowWidthClass.expanded;

  @override
  bool operator ==(Object other) =>
      other is WindowClass && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'WindowClass(${width.name} × ${height.name})';
}
