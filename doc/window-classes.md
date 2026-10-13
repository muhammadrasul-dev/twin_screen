# Window classes

Foldables change size: a Galaxy Z Fold is a 369 dp-wide phone when closed and
a 707 dp-wide tablet when open. Instead of checking device models or exact
pixel widths, decide your layout by **window class**, the Material 3 way of
grouping window sizes. The same rule then covers phones, tablets, desktops,
browser windows and foldables in every posture.

## The classes

| Width class | Width (logical pixels) | Typical window |
|---|---|---|
| `compact` | < 600 | Phone in portrait, cover screen, flip phone |
| `medium` | 600–839 | Unfolded book foldable in portrait, small tablet |
| `expanded` | ≥ 840 | Tablet in landscape, unfolded Pixel Fold, desktop |

| Height class | Height | Typical window |
|---|---|---|
| `compact` | < 480 | Phone in landscape |
| `medium` | 480–899 | Most portrait windows |
| `expanded` | ≥ 900 | Tall tablets, flip phones open |

The class describes the **app window**, not the device: an app in split screen
on a tablet can be compact.

## Reading the class

```dart
final windowClass = WindowClass.of(context);

windowClass.width;      // WindowWidthClass
windowClass.height;     // WindowHeightClass
windowClass.isCompact;  // width is compact
windowClass.isMedium;
windowClass.isExpanded;
```

Classes are ordered, so you can compare them:

```dart
if (WindowClass.of(context).width >= WindowWidthClass.medium) {
  return const TwoColumns();
}
```

Under a `TwinScreenScope`, `WindowClass.of` rebuilds your widget only when the
class changes, not on every resize. That matters on desktop and web, where the
window is resized continuously.

Without a scope, `WindowClass.of` falls back to `MediaQuery.sizeOf` and the
Material 3 breakpoints, so it rebuilds on every resize.

## WindowClassBuilder

Build a different widget per width class:

```dart
WindowClassBuilder(
  compact: (context) => const ScaffoldWithBottomNavigation(),
  medium: (context) => const ScaffoldWithNavigationRail(),
  expanded: (context) => const ScaffoldWithNavigationDrawer(),
)
```

Only `compact` is required. `medium` falls back to `compact`, and `expanded`
falls back to `medium`, then `compact`. To decide on both width and height,
use the `custom` constructor:

```dart
WindowClassBuilder.custom(
  builder: (context, windowClass) {
    if (windowClass.height == WindowHeightClass.compact) {
      return const LandscapePhoneLayout();
    }
    return windowClass.isCompact ? const PhoneLayout() : const TabletLayout();
  },
)
```

## Custom breakpoints

Set your own breakpoints for the whole app on the scope:

```dart
TwinScreenScope(
  breakpoints: const WindowClassBreakpoints(
    mediumWidth: 640,
    expandedWidth: 1000,
    mediumHeight: 480,
    expandedHeight: 900,
  ),
  child: const MyApp(),
)
```

Each value is the smallest size that belongs to that class. A nested
`TwinScreenScope` with different breakpoints changes them for its subtree
only.

You can also compute a class directly:

```dart
WindowClass.fromSize(const Size(700, 900)); // medium × expanded
WindowClassBreakpoints.material3.widthClassOf(599); // compact
```

## Window classes and folds together

Window classes and the fold work together:

- `TwinPane`'s default fallback is by window class: compact shows one pane,
  wider windows show two.
- With the default fallback, a flat fold splits `TwinPane` only on medium or
  wider windows.
- When a foldable reports no posture, a compact window is treated as the cover
  screen.

A good pattern is: choose the overall layout and navigation by window class,
then use `TwinPane` and the `mode` inside it to respect the fold.

## Related

- [Screen state](screen-state.md)
- [TwinPane](twin-pane.md)
