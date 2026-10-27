# twin_screen documentation

Guides for every part of `twin_screen`. Start with **Getting started**, then
read the guide for the feature you need.

| Guide | Read it when you want to |
|---|---|
| [Getting started](getting-started.md) | Add the package and make your first screen fold-aware |
| [Screen state](screen-state.md) | Understand `mode`, posture, hinge, segments and the data source, and read them efficiently |
| [TwinPane](twin-pane.md) | Put two widgets on the two sides of the fold |
| [TwinListDetail](twin-list-detail.md) | Build a list with a detail view that follows the fold |
| [Fold-aware dialog](fold-aware-dialog.md) | Keep dialogs and bottom sheets off the hinge |
| [Window classes](window-classes.md) | Adapt to phones, tablets, desktops and unfolded foldables with one rule |
| [Debug overlay and simulator](debug-overlay.md) | See the fold, and try every foldable without owning one |
| [Platforms](platforms.md) | Know what each platform reports, set up emulators, and understand known quirks |
| [Testing](testing.md) | Write widget tests for fold-aware code |
| [Using with AI coding agents](ai-agents.md) | Give Claude Code, Cursor, Copilot and other agents the rules for writing fold-aware code |
| [FAQ and troubleshooting](faq.md) | Fix common surprises |

The API reference is on
[pub.dev](https://pub.dev/documentation/twin_screen/latest/).

## Words used in these guides

- **Fold**: the line where a flexible screen bends (Galaxy Z Fold, Pixel Fold,
  iPhone Duo). It has no width, and content on it stays visible.
- **Hinge**: a physical gap between two separate screens (Surface Duo).
  Content under it cannot be seen.
- **Segment**: a usable rectangle on one side of the fold or hinge. A window
  that crosses a fold has two segments. Every other window has one.
- **Spanned**: the app window crosses the fold, so it has two segments.
- **Cover screen**: the small outer screen of a closed foldable.
- **Start / end**: the leading and trailing side. Start is the left side in
  left-to-right languages, the right side in right-to-left languages, and the
  top side when the fold is horizontal.
- **Logical pixels**: Flutter's units, equal to Android dp and iOS points. All
  sizes in `twin_screen` use them.
