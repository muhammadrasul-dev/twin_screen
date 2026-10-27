import 'package:flutter/widgets.dart';

import '../models/twin_enums.dart';
import '../models/twin_hinge.dart';
import '../models/twin_screen_data.dart';
import '../models/window_class.dart';
import 'twin_root.dart';
import 'twin_screen_scope.dart';

/// How [TwinPane] lays out its panes when no hinge separates the window.
enum TwinPaneFallback {
  /// Picks by window width class: compact shows [TwinPane.start] only,
  /// medium and expanded show both side by side. The default.
  windowClass,

  /// Shows only [TwinPane.start].
  startOnly,

  /// Shows only [TwinPane.end].
  endOnly,

  /// Shows both panes side by side.
  sideBySide,

  /// Shows both panes stacked, start on top.
  stacked,
}

/// Shows two widgets on the two sides of a fold or hinge.
///
/// 1. When a hinge separates the window (a half-opened fold, or a physical
///    hinge like Surface Duo's), the panes split exactly at the hinge and
///    nothing is placed under it.
/// 2. On a flat fold that does not separate the window, the split lines up
///    with the fold whenever [fallback] would split anyway (by default: window
///    width class medium or larger).
/// 3. Without a fold, [fallback] decides.
///
/// [start] is on the left in left-to-right locales, on the right in
/// right-to-left locales, and on top when the hinge is horizontal. Each pane
/// gets a `MediaQuery` whose padding and display features match its own
/// area, so a `SafeArea` inside a pane does the right thing.
///
/// TwinPane works anywhere on screen, not only full screen: it measures its
/// own position relative to the [TwinScreenScope].
class TwinPane extends StatelessWidget {
  /// Creates a two-pane layout.
  const TwinPane({
    super.key,
    required this.start,
    required this.end,
    this.fallback = TwinPaneFallback.windowClass,
    this.fallbackRatio = 0.5,
    this.maintainHiddenPane = false,
  }) : assert(fallbackRatio > 0 && fallbackRatio < 1);

  /// The leading pane.
  final Widget start;

  /// The trailing pane.
  final Widget end;

  /// The layout used when no hinge separates the window.
  final TwinPaneFallback fallback;

  /// The share of the space given to [start] when the fallback splits
  /// without a fold to align to.
  final double fallbackRatio;

  /// Whether a hidden pane stays in the tree, off screen, so it keeps its
  /// state (scroll position, text input) while the other pane is shown.
  /// Defaults to false: a hidden pane is disposed.
  final bool maintainHiddenPane;

  static const Key _startKey = ValueKey<String>('twin_pane.start');
  static const Key _endKey = ValueKey<String>('twin_pane.end');

  @override
  Widget build(BuildContext context) {
    return RootRegionBuilder(
      builder: (BuildContext context, Rect region, RenderTwinRoot? root) {
        final TwinScreenData data = TwinScreen.of(context, TwinAspect.hinge);
        TwinScreen.of(context, TwinAspect.windowClass);
        final TwinPaneRects rects = TwinPaneRects.resolve(
          region: region,
          hinge: data.hinge,
          widthClass: data.windowClass.width,
          fallback: fallback,
          fallbackRatio: fallbackRatio,
          textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
        );
        final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
        return Stack(
          children: <Widget>[
            if (rects.start ?? (maintainHiddenPane ? region : null) case final Rect rect)
              _pane(_startKey, rect, region, mediaQuery, start, hidden: rects.start == null),
            if (rects.end ?? (maintainHiddenPane ? region : null) case final Rect rect)
              _pane(_endKey, rect, region, mediaQuery, end, hidden: rects.end == null),
          ],
        );
      },
    );
  }

  Widget _pane(
    Key key,
    Rect rect,
    Rect region,
    MediaQueryData? mediaQuery,
    Widget child, {
    required bool hidden,
  }) {
    Widget pane = child;
    if (mediaQuery != null) {
      final Rect screen = Offset.zero & mediaQuery.size;
      final Rect clipped = rect.intersect(screen);
      // Always wrapped, so a pane keeps its state when the split appears.
      pane = MediaQuery(
        data: !clipped.isEmpty && clipped != screen
            ? mediaQuery.removeDisplayFeatures(clipped)
            : mediaQuery,
        child: pane,
      );
    }
    // Always wrapped, so a pane keeps its state when it is hidden or shown.
    pane = Offstage(
      offstage: hidden,
      child: TickerMode(enabled: !hidden, child: pane),
    );
    return Positioned.fromRect(key: key, rect: rect.shift(-region.topLeft), child: pane);
  }
}

/// Where [TwinPane] puts its two panes, in the scope's coordinate space.
///
/// A null rectangle means that pane is hidden.
@immutable
class TwinPaneRects {
  /// Creates pane rectangles.
  const TwinPaneRects({this.start, this.end});

  /// Works out the pane rectangles for a [TwinPane] occupying [region].
  ///
  /// See [TwinPane] for the rules.
  factory TwinPaneRects.resolve({
    required Rect region,
    required TwinHinge? hinge,
    required WindowWidthClass widthClass,
    TwinPaneFallback fallback = TwinPaneFallback.windowClass,
    double fallbackRatio = 0.5,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final bool ltr = textDirection == TextDirection.ltr;
    final TwinPaneFallback resolved = fallback == TwinPaneFallback.windowClass
        ? (widthClass == WindowWidthClass.compact
              ? TwinPaneFallback.startOnly
              : TwinPaneFallback.sideBySide)
        : fallback;
    final bool fallbackSplits =
        resolved == TwinPaneFallback.sideBySide || resolved == TwinPaneFallback.stacked;

    if (hinge != null && _cuts(hinge, region) && (hinge.isSeparating || fallbackSplits)) {
      final Rect b = hinge.bounds;
      if (hinge.axis == TwinHingeAxis.vertical) {
        final Rect left = Rect.fromLTRB(region.left, region.top, b.left, region.bottom);
        final Rect right = Rect.fromLTRB(b.right, region.top, region.right, region.bottom);
        return ltr
            ? TwinPaneRects(start: left, end: right)
            : TwinPaneRects(start: right, end: left);
      }
      return TwinPaneRects(
        start: Rect.fromLTRB(region.left, region.top, region.right, b.top),
        end: Rect.fromLTRB(region.left, b.bottom, region.right, region.bottom),
      );
    }

    switch (resolved) {
      case TwinPaneFallback.startOnly:
      case TwinPaneFallback.windowClass:
        return TwinPaneRects(start: region);
      case TwinPaneFallback.endOnly:
        return TwinPaneRects(end: region);
      case TwinPaneFallback.sideBySide:
        final double split = region.left + region.width * (ltr ? fallbackRatio : 1 - fallbackRatio);
        final Rect left = Rect.fromLTRB(region.left, region.top, split, region.bottom);
        final Rect right = Rect.fromLTRB(split, region.top, region.right, region.bottom);
        return ltr
            ? TwinPaneRects(start: left, end: right)
            : TwinPaneRects(start: right, end: left);
      case TwinPaneFallback.stacked:
        final double split = region.top + region.height * fallbackRatio;
        return TwinPaneRects(
          start: Rect.fromLTRB(region.left, region.top, region.right, split),
          end: Rect.fromLTRB(region.left, split, region.right, region.bottom),
        );
    }
  }

  /// The leading pane, or null when hidden.
  final Rect? start;

  /// The trailing pane, or null when hidden.
  final Rect? end;

  /// Whether both panes are shown.
  bool get isSplit => start != null && end != null;

  /// Whether [hinge] runs through the inside of [region].
  static bool _cuts(TwinHinge hinge, Rect region) {
    final Rect b = hinge.bounds;
    return switch (hinge.axis) {
      TwinHingeAxis.vertical =>
        b.left > region.left &&
            b.right < region.right &&
            b.top < region.bottom &&
            b.bottom > region.top,
      TwinHingeAxis.horizontal =>
        b.top > region.top &&
            b.bottom < region.bottom &&
            b.left < region.right &&
            b.right > region.left,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is TwinPaneRects && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TwinPaneRects(start: $start, end: $end)';
}
