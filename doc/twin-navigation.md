# TwinNavigation

A bottom bar is right on a phone and wrong on a tablet or an open foldable,
where a rail on the side uses the space better. On a foldable with a vertical
hinge, a full-width bottom bar would also be cut in two. `TwinNavigation` chooses
for you.

```dart
TwinNavigation(
  destinations: const [
    TwinDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox), label: 'Inbox'),
    TwinDestination(icon: Icon(Icons.send_outlined), label: 'Sent'),
  ],
  selectedIndex: _index,
  onDestinationSelected: (i) => setState(() => _index = i),
  body: pages[_index],
)
```

## Which navigation

With `layout: TwinNavigationLayout.auto` (the default):

| Situation | Navigation |
|---|---|
| A vertical hinge separates the window | rail |
| Compact window width | bottom bar |
| Medium window width | rail |
| Expanded window width | extended rail (labels beside the icons) |

The rail sits on the start edge (the right in right-to-left locales), so it is
never under the hinge. A horizontal hinge (tabletop) keeps the bottom bar, which
sits in the lower half.

Pass `layout: TwinNavigationLayout.bottomBar`, `.rail` or `.extendedRail` to
force one. `TwinNavigation.resolve(...)` is the pure function behind the choice.

## The body

`body` fills the space next to the navigation. It can hold a `TwinPane` or a
`TwinListDetail`; they measure their own position, so they still split exactly
at the fold.

## Rail extras

`railLeading` (for example a floating action button) and `railTrailing` are
shown on a rail and ignored by the bottom bar.

## Notes

- Use it as the `body` of a `Scaffold`, or on its own. Do not combine it with
  `Scaffold.bottomNavigationBar`.
- Give it a bounded size.
- It needs at least two destinations.
