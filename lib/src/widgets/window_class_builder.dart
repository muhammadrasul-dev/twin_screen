import 'package:flutter/widgets.dart';

import '../models/window_class.dart';

/// Builds a different widget for each window width class.
///
/// [medium] falls back to [compact], and [expanded] falls back to [medium]
/// and then [compact], so only [compact] is required:
///
/// ```dart
/// WindowClassBuilder(
///   compact: (context) => const PhoneLayout(),
///   expanded: (context) => const TabletLayout(),
/// )
/// ```
///
/// The widget rebuilds only when the width class changes. Use
/// [WindowClassBuilder.custom] to decide on both width and height.
class WindowClassBuilder extends StatelessWidget {
  /// Creates a builder that picks by width class.
  const WindowClassBuilder({
    super.key,
    required WidgetBuilder this.compact,
    this.medium,
    this.expanded,
  }) : builder = null;

  /// Creates a builder that receives the full [WindowClass].
  const WindowClassBuilder.custom({
    super.key,
    required Widget Function(BuildContext context, WindowClass windowClass) this.builder,
  }) : compact = null,
       medium = null,
       expanded = null;

  /// Builds the compact layout, and any class without its own builder.
  final WidgetBuilder? compact;

  /// Builds the medium layout. Defaults to [compact].
  final WidgetBuilder? medium;

  /// Builds the expanded layout. Defaults to [medium], then [compact].
  final WidgetBuilder? expanded;

  /// Builds from the full window class. Set by [WindowClassBuilder.custom].
  final Widget Function(BuildContext context, WindowClass windowClass)? builder;

  @override
  Widget build(BuildContext context) {
    final WindowClass windowClass = WindowClass.of(context);
    final Widget Function(BuildContext, WindowClass)? custom = builder;
    if (custom != null) return custom(context, windowClass);
    final WidgetBuilder chosen = switch (windowClass.width) {
      WindowWidthClass.compact => compact!,
      WindowWidthClass.medium => medium ?? compact!,
      WindowWidthClass.expanded => expanded ?? medium ?? compact!,
    };
    return chosen(context);
  }
}
