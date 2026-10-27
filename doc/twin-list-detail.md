# TwinListDetail

The list-and-detail screen is the most common use of two panes. `TwinListDetail`
does the layout and the back handling for you.

```dart
class _InboxState extends State<Inbox> {
  Message? _selected;

  @override
  Widget build(BuildContext context) {
    return TwinListDetail(
      list: MessageList(onSelected: (m) => setState(() => _selected = m)),
      detail: _selected == null ? null : MessageView(message: _selected!),
      placeholder: const Center(child: Text('Select a message')),
      onDetailClosed: () => setState(() => _selected = null),
    );
  }
}
```

## Layout

`TwinListDetail` splits in the same cases as [`TwinPane`](twin-pane.md):

- a hinge separates the window: split exactly at the hinge;
- a flat fold, or no fold, on a medium or larger window: side by side;
- a compact window (phone, cover screen): one view at a time.

When split, `list` is on the start side and `detail` on the end side. While
`detail` is null the end side shows `placeholder` (an empty box by default).
`listRatio` (default 0.4) sets the list's share when there is no fold to align
to.

When not split, `list` shows until `detail` is non-null, then `detail` replaces
it. The back gesture calls `onDetailClosed`; set the selection to null there.
Without `onDetailClosed` the back gesture is left alone.

## State

Both views stay in the tree, so the list keeps its scroll position and any
text input while the detail is shown, and the other way round. Folding or
unfolding the device does not rebuild them from scratch.

## Knowing the layout

Inside `list` or `detail`, `TwinListDetail.isSplitOf(context)` returns true when
the two are side by side. Use it to show a back button only when stacked:

```dart
AppBar(
  automaticallyImplyLeading: !TwinListDetail.isSplitOf(context),
)
```

The call registers a dependency, so the widget rebuilds when the answer
changes.

## Notes

- Give it a bounded size, such as a `Scaffold` body.
- To build your own variant, use [`TwinPane`](twin-pane.md) with
  `maintainHiddenPane: true` so a hidden pane keeps its state.
