# Fold-aware dialog

A dialog is centred in the window. On a spanned foldable the centre is the
fold, so a plain dialog ends up bent over the crease, or split by Surface Duo's
hinge. `showFoldAwareDialog` keeps it on one side.

```dart
showFoldAwareDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Discard draft?'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
    ],
  ),
);
```

It returns the same `Future` as `showDialog` and accepts the same options
(`barrierDismissible`, `barrierColor`, `barrierLabel`, `useSafeArea`,
`useRootNavigator`, `routeSettings`, `traversalEdgeBehavior`).

## Which side

The dialog goes to one segment, chosen like this:

1. **`anchorPoint`**, a global position: the side that holds that point. Pass
   the position of the tap that opened the dialog, so it appears where the
   user is looking:

   ```dart
   GestureDetector(
     onTapDown: (details) => showFoldAwareDialog<void>(
       context: context,
       anchorPoint: details.globalPosition,
       builder: (context) => const AlertDialog(title: Text('Details')),
     ),
     child: const ListTile(title: Text('Order #1042')),
   )
   ```

   A point under the hinge goes to the nearest side.

2. **`preferredSide`**, when there is no anchor: `TwinPaneSide.start`
   (default) or `TwinPaneSide.end`. Start follows the text direction (left in
   LTR, right in RTL) and is the top side for a horizontal fold.

3. **`allowSpanning: true`** lets the dialog use both sides. Use it for large
   content that is designed to cross the fold, such as a full-width picker on
   a flat foldable.

Without a fold, all three behave like `showDialog`.

The barrier still covers the whole screen; only the dialog itself is placed
on one side.

## Inside the dialog

The dialog's `MediaQuery` contains only its own side's padding and display
features, so a dialog's own layout never sees the fold. With `allowSpanning`,
the fold and hinge are removed from its `MediaQuery` entirely, so the dialog
lays out as on one big screen.

## `FoldAwareDialog` for custom routes

The placement is also available as a widget, for your own routes, overlays,
bottom sheets or popovers:

```dart
Navigator.of(context).push(
  PageRouteBuilder<void>(
    opaque: false,
    barrierDismissible: true,
    pageBuilder: (context, _, _) => const FoldAwareDialog(
      preferredSide: TwinPaneSide.end,
      child: Center(child: MyPopover()),
    ),
  ),
);
```

`FoldAwareDialog` fills the space it is given and pads its child into the
chosen segment. `FoldAwareDialogRoute` is the `DialogRoute` that
`showFoldAwareDialog` pushes, if you want to push it yourself.

## Flutter's own `showDialog`

Flutter's `showDialog(anchorPoint: ...)` also avoids folds, using
`DisplayFeatureSubScreen`. On Android that already works. `twin_screen` writes
iOS and web folds into `MediaQuery.displayFeatures`, so it now works there too.
`showFoldAwareDialog` adds `preferredSide`, `allowSpanning` and RTL-aware
sides on top.

## Related

- [TwinPane](twin-pane.md)
- [Screen state](screen-state.md)

## Bottom sheets

`showFoldAwareBottomSheet` applies the same rules to a modal bottom sheet. It
takes `anchorPoint`, `preferredSide` and `allowSpanning`, plus the arguments of
`showModalBottomSheet` (`isScrollControlled`, `showDragHandle`, `constraints`,
`useSafeArea` and so on).

```dart
showFoldAwareBottomSheet<void>(
  context: context,
  anchorPoint: details.globalPosition,
  builder: (context) => const SizedBox(height: 240, child: Center(child: Text('Share'))),
);
```

The sheet rises from the bottom of its side. On a horizontal fold (tabletop),
`TwinPaneSide.end` is the bottom half, so the sheet sits there. The scrim covers
the whole screen. `FoldAwareBottomSheetRoute` is the route, for `Navigator.push`.
