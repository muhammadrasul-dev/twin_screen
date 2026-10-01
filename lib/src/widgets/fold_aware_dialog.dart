import 'dart:math' as math;
import 'dart:ui' show DisplayFeature;

import 'package:flutter/material.dart';

import '../core/twin_resolver.dart';
import '../models/twin_enums.dart';
import '../models/twin_screen_data.dart';
import 'twin_root.dart';
import 'twin_screen_scope.dart';

/// Keeps a dialog on one side of the fold.
///
/// When the window spans a fold, [child] is placed in one segment:
///
/// * the segment that contains [anchorPoint], if given;
/// * otherwise the [preferredSide] segment.
///
/// With [allowSpanning] the child may cover both segments. Without a fold the
/// child fills the whole area.
///
/// [showFoldAwareDialog] uses this widget. Use it directly for custom routes
/// and overlays.
class FoldAwareDialog extends StatelessWidget {
  /// Creates a fold-aware dialog placement.
  const FoldAwareDialog({
    super.key,
    required this.child,
    this.anchorPoint,
    this.preferredSide = TwinPaneSide.start,
    this.allowSpanning = false,
  });

  /// The dialog.
  final Widget child;

  /// A global position, for example `TapDownDetails.globalPosition`. The
  /// dialog opens on the side of the fold that holds this point.
  final Offset? anchorPoint;

  /// The side used when there is no [anchorPoint]. Defaults to
  /// [TwinPaneSide.start].
  final TwinPaneSide preferredSide;

  /// Whether the dialog may cover both sides of the fold.
  final bool allowSpanning;

  @override
  Widget build(BuildContext context) {
    return RootRegionBuilder(
      builder: (BuildContext context, Rect region, RenderTwinRoot? measuredRoot) {
        final TwinScreenData data = TwinScreen.of(context, TwinAspect.segments);
        final MediaQueryData mediaQuery = MediaQuery.of(context);
        final RenderTwinRoot? root =
            measuredRoot ?? context.findAncestorRenderObjectOfType<RenderTwinRoot>();

        Rect target = region;
        if (!allowSpanning && data.segments.length > 1) {
          final Offset? anchor = switch (anchorPoint) {
            final Offset global => root?.globalToRoot(global) ?? global,
            null => null,
          };
          final Rect segment = anchor != null
              ? _segmentNearest(data.segments, anchor)
              : data.segmentFor(preferredSide);
          final Rect clipped = segment.intersect(region);
          if (!clipped.isEmpty) target = clipped;
        }

        MediaQueryData inner = mediaQuery;
        final Rect screen = Offset.zero & mediaQuery.size;
        final Rect clippedTarget = target.intersect(screen);
        if (!clippedTarget.isEmpty && clippedTarget != screen) {
          inner = inner.removeDisplayFeatures(clippedTarget);
        }
        if (allowSpanning) {
          inner = inner.copyWith(
            displayFeatures: <DisplayFeature>[
              for (final DisplayFeature f in inner.displayFeatures)
                if (!TwinResolver.isFoldOrHinge(f)) f,
            ],
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            target.left - region.left,
            target.top - region.top,
            region.right - target.right,
            region.bottom - target.bottom,
          ),
          child: MediaQuery(data: inner, child: child),
        );
      },
    );
  }

  static Rect _segmentNearest(List<Rect> segments, Offset point) {
    Rect best = segments.first;
    double bestDistance = double.infinity;
    for (final Rect segment in segments) {
      final double dx = math.max(0, math.max(segment.left - point.dx, point.dx - segment.right));
      final double dy = math.max(0, math.max(segment.top - point.dy, point.dy - segment.bottom));
      final double distance = dx * dx + dy * dy;
      if (distance < bestDistance) {
        best = segment;
        bestDistance = distance;
      }
    }
    return best;
  }
}

/// Shows a Material dialog that stays on one side of the fold.
///
/// Works like `showDialog`, with placement rules from [FoldAwareDialog]:
/// the dialog opens on the side that holds [anchorPoint] (a global position),
/// or on [preferredSide] when there is no anchor. Set [allowSpanning] to let
/// it cover both sides.
///
/// ```dart
/// GestureDetector(
///   onTapDown: (details) => showFoldAwareDialog<void>(
///     context: context,
///     anchorPoint: details.globalPosition,
///     builder: (context) => const AlertDialog(title: Text('Hello')),
///   ),
/// )
/// ```
Future<T?> showFoldAwareDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Offset? anchorPoint,
  TwinPaneSide preferredSide = TwinPaneSide.start,
  bool allowSpanning = false,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  TraversalEdgeBehavior? traversalEdgeBehavior,
}) {
  assert(debugCheckHasMaterialLocalizations(context));
  final NavigatorState navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final CapturedThemes themes = InheritedTheme.capture(from: context, to: navigator.context);
  return navigator.push<T>(
    FoldAwareDialogRoute<T>(
      context: context,
      builder: builder,
      themes: themes,
      anchorPoint: anchorPoint,
      preferredSide: preferredSide,
      allowSpanning: allowSpanning,
      barrierColor: barrierColor ?? Theme.of(context).dialogTheme.barrierColor ?? Colors.black54,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      settings: routeSettings,
      traversalEdgeBehavior: traversalEdgeBehavior ?? TraversalEdgeBehavior.closedLoop,
    ),
  );
}

/// A Material [DialogRoute] that places its dialog with [FoldAwareDialog].
class FoldAwareDialogRoute<T> extends DialogRoute<T> {
  /// Creates a fold-aware dialog route.
  FoldAwareDialogRoute({
    required super.context,
    required super.builder,
    super.themes,
    super.barrierColor = Colors.black54,
    super.barrierDismissible,
    super.barrierLabel,
    super.useSafeArea,
    super.settings,
    super.anchorPoint,
    super.traversalEdgeBehavior,
    this.preferredSide = TwinPaneSide.start,
    this.allowSpanning = false,
  });

  /// See [FoldAwareDialog.preferredSide].
  final TwinPaneSide preferredSide;

  /// See [FoldAwareDialog.allowSpanning].
  final bool allowSpanning;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return FoldAwareDialog(
      anchorPoint: anchorPoint,
      preferredSide: preferredSide,
      allowSpanning: allowSpanning,
      child: super.buildPage(context, animation, secondaryAnimation),
    );
  }
}
