import 'package:flutter/material.dart';

import '../models/twin_enums.dart';
import '../models/twin_hinge.dart';
import '../models/window_class.dart';
import 'twin_screen_scope.dart';

/// One destination of a [TwinNavigation].
@immutable
class TwinDestination {
  /// Creates a destination.
  const TwinDestination({required this.icon, required this.label, this.selectedIcon});

  /// The icon shown when the destination is not selected.
  final Widget icon;

  /// The icon shown when the destination is selected. Defaults to [icon].
  final Widget? selectedIcon;

  /// The text label.
  final String label;
}

/// How [TwinNavigation] shows its destinations.
enum TwinNavigationLayout {
  /// Picks by window and fold: a [bottomBar] on compact windows, a [rail] on
  /// medium ones, an [extendedRail] on expanded ones. A vertical hinge that
  /// separates the window always gets a [rail], since a bottom bar would be
  /// cut in two. The default.
  auto,

  /// A `NavigationBar` along the bottom edge.
  bottomBar,

  /// A `NavigationRail` along the start edge, with labels under the icons.
  rail,

  /// A `NavigationRail` along the start edge, with labels beside the icons.
  extendedRail,
}

/// Navigation that adapts to the window and the fold.
///
/// Shows a bottom bar on a phone, a rail on a medium window or an unfolded
/// foldable, and an extended rail on a large window. A rail sits on the start
/// edge (left in left-to-right locales), so it never ends up under a hinge.
/// With a separating vertical hinge the rail is used even on a compact window.
///
/// [body] fills the rest of the space. It can itself contain a `TwinPane` or
/// a `TwinListDetail`, which still split at the fold.
///
/// ```dart
/// TwinNavigation(
///   destinations: const [
///     TwinDestination(icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
///     TwinDestination(icon: Icon(Icons.send_outlined), label: 'Sent'),
///   ],
///   selectedIndex: _index,
///   onDestinationSelected: (i) => setState(() => _index = i),
///   body: pages[_index],
/// )
/// ```
///
/// Use it as the `body` of a `Scaffold` (or on its own); do not combine it with
/// `Scaffold.bottomNavigationBar`.
class TwinNavigation extends StatelessWidget {
  /// Creates adaptive navigation.
  const TwinNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.layout = TwinNavigationLayout.auto,
    this.railLeading,
    this.railTrailing,
  }) : assert(destinations.length >= 2, 'Navigation needs at least two destinations.');

  /// The destinations, at least two.
  final List<TwinDestination> destinations;

  /// The index of the selected destination.
  final int selectedIndex;

  /// Called with the index of the destination the user picked.
  final ValueChanged<int> onDestinationSelected;

  /// The content next to (or above) the navigation.
  final Widget body;

  /// How to show the destinations. Defaults to [TwinNavigationLayout.auto].
  final TwinNavigationLayout layout;

  /// A widget at the top of a rail, such as a floating action button. Not used
  /// by the bottom bar.
  final Widget? railLeading;

  /// A widget at the bottom of a rail. Not used by the bottom bar.
  final Widget? railTrailing;

  /// Picks the concrete layout for [layout].
  ///
  /// Never returns [TwinNavigationLayout.auto]. [hingeSeparatesVertically] is
  /// true when a vertical hinge splits the window in two.
  static TwinNavigationLayout resolve({
    required TwinNavigationLayout layout,
    required WindowWidthClass widthClass,
    bool hingeSeparatesVertically = false,
  }) {
    if (layout != TwinNavigationLayout.auto) return layout;
    if (hingeSeparatesVertically && widthClass == WindowWidthClass.compact) {
      return TwinNavigationLayout.rail;
    }
    return switch (widthClass) {
      WindowWidthClass.compact => TwinNavigationLayout.bottomBar,
      WindowWidthClass.medium => TwinNavigationLayout.rail,
      WindowWidthClass.expanded => TwinNavigationLayout.extendedRail,
    };
  }

  @override
  Widget build(BuildContext context) {
    final TwinHinge? hinge = TwinScreen.of(context, TwinAspect.hinge).hinge;
    final WindowWidthClass widthClass = TwinScreen.of(
      context,
      TwinAspect.windowClass,
    ).windowClass.width;
    final TwinNavigationLayout resolved = resolve(
      layout: layout,
      widthClass: widthClass,
      hingeSeparatesVertically:
          hinge != null && hinge.isSeparating && hinge.axis == TwinHingeAxis.vertical,
    );

    if (resolved == TwinNavigationLayout.bottomBar) {
      return Column(
        children: <Widget>[
          Expanded(child: body),
          NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: <Widget>[
              for (final TwinDestination d in destinations)
                NavigationDestination(icon: d.icon, selectedIcon: d.selectedIcon, label: d.label),
            ],
          ),
        ],
      );
    }

    final bool extended = resolved == TwinNavigationLayout.extendedRail;
    return Row(
      children: <Widget>[
        NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          extended: extended,
          labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
          leading: railLeading,
          trailing: railTrailing,
          destinations: <NavigationRailDestination>[
            for (final TwinDestination d in destinations)
              NavigationRailDestination(
                icon: d.icon,
                selectedIcon: d.selectedIcon,
                label: Text(d.label),
              ),
          ],
        ),
        Expanded(child: body),
      ],
    );
  }
}
