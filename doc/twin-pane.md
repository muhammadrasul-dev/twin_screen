# TwinPane

`TwinPane` shows two widgets, `start` and `end`, on the two sides of a fold or
hinge. On screens without a fold it falls back to a layout that you choose. It
is the building block for list-detail, master-detail, two-page and
content-plus-controls layouts.

```dart
TwinPane(
  start: const ChatList(),
  end: const ChatView(),
)
```

## How it decides

`TwinPane` applies three rules, in order.

### 1. A separating hinge splits exactly at the hinge

A hinge *separates* the window when the device is half-open, or when it is a
physical hinge with width (Surface Duo). The two sides are then physically
distinct surfaces, so `TwinPane` always splits there:

- vertical hinge → `start` on the left, `end` on the right (swapped in RTL);
- horizontal hinge → `start` on top, `end` below.

Nothing is placed under a hinge that hides content. On Surface Duo, the 34 dp
gap between the panels stays empty.

### 2. A flat fold aligns the split with the fold

A flat fold does not separate the window: the screen is continuous, and an app
may use it as one big screen. `TwinPane` therefore splits only when it would
split anyway (see `fallback`), and then puts the split exactly on the fold
instead of at `fallbackRatio`. With the default fallback, that means a flat
fold splits the panes on medium and expanded windows (an unfolded Galaxy Z
Fold or Pixel Fold) but not on compact ones (an unfolded Galaxy Z Flip).

### 3. No fold: the fallback decides

| `fallback` | Result |
|---|---|
| `windowClass` (default) | compact width → `start` only; medium and expanded → side by side |
| `startOnly` | Only `start` |
| `endOnly` | Only `end` |
| `sideBySide` | Both, `start` leading |
| `stacked` | Both, `start` on top |

`fallbackRatio` (default `0.5`) is the share of space `start` gets when the
fallback splits and there is no fold to follow:

```dart
TwinPane(
  start: const Navigation(),
  end: const Content(),
  fallback: TwinPaneFallback.sideBySide,
  fallbackRatio: 0.3,
)
```

## What each pane receives

Each pane gets its own `MediaQuery`, built with Flutter's
`MediaQueryData.removeDisplayFeatures`:

- **Padding**: only the safe-area insets on the pane's own edges. The left pane
  keeps the left inset and loses the right one, and so on. `SafeArea` inside a
  pane does the right thing.
- **Display features**: only the features inside the pane, so Flutter's
  `DisplayFeatureSubScreen` inside a pane sees no fold. (A nested `TwinPane`
  or `FoldAwareDialog` reads the hinge from the scope instead; it ignores the
  fold because the fold does not cross its own space.)

The `MediaQuery` size is left unchanged, as in Flutter's own
`DisplayFeatureSubScreen`. Use a `LayoutBuilder` inside a pane if you need its
size.

## Placement anywhere

`TwinPane` does not need to fill the screen. It measures its own position
relative to the `TwinScreenScope` after layout, so it works:

- as a `Scaffold` body, below an `AppBar`;
- next to a navigation rail;
- inside a page that is animating in (it uses the layout position, ignoring
  transition transforms, so it does not jump during page transitions).

If the hinge does not run through the space `TwinPane` occupies, rule 3
applies. `TwinPane` needs bounded constraints: give it a finite width and
height, as a `Scaffold` body or inside `Expanded` does.

## List and detail with navigation

When the panes are split, selecting an item should update `end`. When they are
not, it should open the detail as a page. `TwinPaneRects.resolve` runs the
same rules without building anything:

```dart
final screen = TwinScreen.of(context);
final split = TwinPaneRects.resolve(
  region: Offset.zero & screen.size,
  hinge: screen.hinge,
  widthClass: screen.windowClass.width,
).isSplit;
```

`TwinPaneRects` also gives you the two rectangles (`start` and `end`, null
when hidden), in case you build a custom layout.

## Recipes

**Video on top, controls below, on a half-open flip phone; full screen
otherwise:**

```dart
final mode = TwinScreen.modeOf(context);

return mode == TwinScreenMode.tabletop
    ? TwinPane(start: const VideoPlayer(), end: const PlayerControls())
    : const VideoPlayerWithOverlayControls();
```

**Always two panes, stacked on phones:**

```dart
TwinPane(
  start: const MapView(),
  end: const PlaceDetails(),
  fallback: TwinPaneFallback.stacked,
  fallbackRatio: 0.6,
)
```

**Two pages of a book reader:**

```dart
TwinPane(
  start: BookPage(number: page),
  end: BookPage(number: page + 1),
  fallback: TwinPaneFallback.startOnly,
)
```

## Related

- [Screen state](screen-state.md): the `hinge` and `segments` that `TwinPane`
  uses.
- [Fold-aware dialog](fold-aware-dialog.md): the same idea for dialogs.

## Knowing whether it split

Inside either pane, `TwinPane.isSplitOf(context)` returns true when both panes
are showing. Use it to choose between selecting an item (the detail is already
visible) and opening it as a page:

```dart
onTap: () {
  if (TwinPane.isSplitOf(context)) {
    setState(() => _selected = item);
  } else {
    Navigator.of(context).push(detailRoute(item));
  }
}
```

It uses the layout's own rules, so it cannot disagree with what is on screen,
and it rebuilds the caller when the answer changes. From outside a `TwinPane`
(a parent that has no pane above it), compute the rules yourself with
`TwinPaneRects.resolve(...).isSplit`.

## Hidden panes

When only one pane shows (a phone, the cover screen), the other pane is not in
the tree by default, so its state is lost when it disappears. `hiddenPane`
changes that:

| Value | Hidden pane |
|---|---|
| `TwinHiddenPane.dispose` (default) | removed; state lost |
| `TwinHiddenPane.keepOnceShown` | built the first time it shows; then kept, off screen, with its state |
| `TwinHiddenPane.keep` | always built, off screen, from the first frame |

`keepOnceShown` suits a list that must keep its scroll position while a detail
is open, without building a detail nobody has opened. `TwinListDetail` uses it.
