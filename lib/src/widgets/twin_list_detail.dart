import 'package:flutter/widgets.dart';

import '../models/twin_screen_data.dart';
import 'twin_pane.dart';
import 'twin_root.dart';
import 'twin_screen_scope.dart';

/// A list and its detail view, laid out for the fold.
///
/// When the window splits (a half-opened fold, a physical hinge, or a medium or
/// larger window class), [list] is on the start side and [detail] on the end
/// side. [placeholder] fills the end side while nothing is selected.
///
/// When it does not split (a phone, the cover screen), only one of them shows:
/// [list] while [detail] is null, [detail] once something is selected. The
/// system back gesture then calls [onDetailClosed], so clear the selection
/// there.
///
/// ```dart
/// TwinListDetail(
///   list: ItemList(onSelected: (item) => setState(() => _selected = item)),
///   detail: _selected == null ? null : ItemDetail(item: _selected!),
///   placeholder: const Center(child: Text('Select an item')),
///   onDetailClosed: () => setState(() => _selected = null),
/// )
/// ```
///
/// Both views keep their state (scroll position, text input) while the other
/// one is shown. Use [TwinListDetail.isSplitOf] inside either view to show a
/// back button only when the views are stacked.
class TwinListDetail extends StatelessWidget {
  /// Creates a list and detail layout.
  const TwinListDetail({
    super.key,
    required this.list,
    this.detail,
    this.placeholder,
    this.onDetailClosed,
    this.listRatio = 0.4,
  }) : assert(listRatio > 0 && listRatio < 1);

  /// The list.
  final Widget list;

  /// The selected item's detail, or null when nothing is selected.
  final Widget? detail;

  /// Shown on the end side of a split layout while [detail] is null. Defaults
  /// to an empty box.
  final Widget? placeholder;

  /// Called when the back gesture should close [detail]. Only used when the
  /// views are stacked and [detail] is showing.
  final VoidCallback? onDetailClosed;

  /// The share of the width given to [list] when the layout splits without a
  /// fold to align to.
  final double listRatio;

  /// Whether the nearest [TwinListDetail] shows its views side by side.
  ///
  /// Returns false when there is none. Registers a dependency, so the caller
  /// rebuilds when the answer changes.
  static bool isSplitOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SplitScope>()?.isSplit ?? false;

  @override
  Widget build(BuildContext context) {
    return RootRegionBuilder(
      builder: (BuildContext context, Rect region, RenderTwinRoot? root) {
        final TwinScreenData data = TwinScreen.of(context, TwinAspect.hinge);
        TwinScreen.of(context, TwinAspect.windowClass);
        final bool split = TwinPaneRects.resolve(
          region: region,
          hinge: data.hinge,
          widthClass: data.windowClass.width,
          fallbackRatio: listRatio,
          textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
        ).isSplit;
        final bool detailShown = !split && detail != null;

        return _SplitScope(
          isSplit: split,
          child: PopScope(
            canPop: !detailShown || onDetailClosed == null,
            onPopInvokedWithResult: (bool didPop, Object? result) {
              if (!didPop) onDetailClosed?.call();
            },
            child: TwinPane(
              start: list,
              end: detail ?? placeholder ?? const SizedBox.shrink(),
              fallback: split
                  ? TwinPaneFallback.sideBySide
                  : (detailShown ? TwinPaneFallback.endOnly : TwinPaneFallback.startOnly),
              fallbackRatio: listRatio,
              maintainHiddenPane: true,
            ),
          ),
        );
      },
    );
  }
}

class _SplitScope extends InheritedWidget {
  const _SplitScope({required this.isSplit, required super.child});

  final bool isSplit;

  @override
  bool updateShouldNotify(_SplitScope oldWidget) => isSplit != oldWidget.isSplit;
}
