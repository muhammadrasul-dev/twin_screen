# Using twin_screen with AI coding agents

Claude Code, Cursor, GitHub Copilot, Gemini CLI, Codex and similar agents can
write fold-aware Flutter code with `twin_screen`. Left alone, though, they
reach for patterns that break on foldables: checking device model names,
hard-coding pixel widths, centring dialogs on the fold, or forgetting
`TwinScreenScope`. This guide gives you the rules to hand your agent, prompts
that work well, and a way to check its work without owning a foldable.

## 1. Give your agent the rules

Most agents read a project instructions file on every request. Copy the block
below into the one your tool uses:

| Agent | File |
|---|---|
| Claude Code | `CLAUDE.md` |
| Codex, Jules, Amp and other `AGENTS.md` readers | `AGENTS.md` |
| Cursor | `.cursor/rules/twin_screen.mdc` (or `AGENTS.md`) |
| GitHub Copilot | `.github/copilot-instructions.md` |
| Gemini CLI | `GEMINI.md` |
| Windsurf | `.windsurf/rules/twin_screen.md` |

````markdown
## Foldables and dual screens: twin_screen

This app uses `package:twin_screen` for foldable, flip, dual-screen and
large-screen layouts. Guides: https://github.com/muhammadrasul-dev/twin_screen/tree/main/doc

### Setup
- `TwinScreenScope` wraps the whole app, ABOVE `MaterialApp` / `CupertinoApp` /
  `MaterialApp.router`. `TwinDebugOverlay` goes inside the scope and also above
  `MaterialApp`. The overlay turns itself off in release builds.
- Import only `package:twin_screen/twin_screen.dart`, never `package:twin_screen/src/...`.

### Reading the state
- Decide layouts by `TwinScreenMode` (`standard`, `cover`, `singlePane`,
  `dualPane`, `book`, `tabletop`) and by `WindowClass`. Never by device model
  names, `Platform.isIOS`, or hard-coded pixel widths.
- Use the narrow readers: `TwinScreen.modeOf`, `postureOf`, `isSpannedOf`,
  `hingeOf`, `segmentsOf`, `deviceTypeOf`, `WindowClass.of`. Plain
  `TwinScreen.of(context)` rebuilds on every degree of hinge movement.
- To follow the hinge angle (animations), listen to
  `TwinScreen.hingeAngleStreamOf(context)` instead of rebuilding.
- `hingeAngle` and `hinge` are nullable: most devices have no hinge sensor
  or no fold. The first frame may report `deviceType: unknown`; do not cache it.

### Layout
- Two kinds of content side by side: `TwinPane(start: ..., end: ...)`. Do not
  compute the split yourself, and never place content under `hinge.bounds`
  when `hinge.occludesContent` is true.
- Use `start` / `end`, not left / right: start is left in LTR, right in RTL,
  and the top side when the fold is horizontal.
- `TwinPane` needs bounded constraints (a `Scaffold` body, `Expanded`, `SizedBox`).
- Where only one pane fits, `TwinPane` shows `start` (default
  `fallback: TwinPaneFallback.windowClass`).
- List and detail: `TwinListDetail(list:, detail:, onDetailClosed:)`. Do not
  hand-roll the split or push the detail as a route.
- Bottom bar or rail: `TwinNavigation(destinations:, selectedIndex:,
  onDestinationSelected:, body:)`, not a fixed `NavigationBar`.
- Other layouts that adapt to size: `WindowClassBuilder(compact: ..., medium: ..., expanded: ...)`.
- `tabletop` mode: content on top, controls below the fold.

### Dialogs
- Use `showFoldAwareDialog` instead of `showDialog`. Pass
  `anchorPoint: details.globalPosition` from the tap that opened it, when there is one.
- Bottom sheets: `showFoldAwareBottomSheet` instead of `showModalBottomSheet`.

### Tests
- No hardware needed. Build a device with
  `TwinSimulatedScreen.resolve(preset: TwinDevicePreset.galaxyZFold, posture: TwinPosture.halfOpened, hingeAngle: 110, orientation: Orientation.portrait, span: TwinSimulatedSpan.both)`,
  set `tester.view.physicalSize = screen.size` and `tester.view.devicePixelRatio = 1`,
  and pump `TwinScreenScope(platformOverride: screen.platform.copyWith(displayFeatures: screen.displayFeatures), child: ...)`.
- Call `await tester.pump()` once more after `pumpWidget`: `TwinPane` measures
  its position after the first frame.
- Loop over `TwinDevicePreset.all` × `TwinPosture.closed / halfOpened / flat`
  (skip `closed` when `!preset.hasCover`) and expect no exceptions, to catch
  overflows on every foldable shape.
````

The block is short on purpose: agents follow a few precise rules better than a
long manual. It links to the full guides for anything else.

## 2. Let the agent read the docs offline

The package ships with its guides. After `flutter pub get`, an agent can read
them from the pub cache without a web browser:

```sh
# macOS and Linux
ls ~/.pub-cache/hosted/pub.dev/twin_screen-*/doc/
# Windows
dir %LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\twin_screen-*\doc\
```

The exact path is in `.dart_tool/package_config.json` (look for
`"name": "twin_screen"`). Every public class and method also has dartdoc
comments, which agents that read source files pick up directly. You can tell
your agent: *"Read the twin_screen guides in the pub cache before you start."*

## 3. Prompts that work well

Name the package, the widget and the behaviour you expect on each kind of
screen. Some starting points:

**Make a list-detail screen fold-aware**

> Use twin_screen's `TwinPane` on `InboxPage`: the message list is `start`,
> the open message is `end`. When the panes are not split, open the message as
> a new route instead. Keep the current behaviour on phones.

**A video player for tabletop mode**

> When `TwinScreen.modeOf(context)` is `tabletop`, show the video in `start`
> and the playback controls in `end` of a `TwinPane`. In every other mode keep
> the current full-screen player.

**Keep dialogs off the fold**

> Replace every `showDialog` call with `showFoldAwareDialog`. Where the dialog
> is opened from a tap, pass the tap position as `anchorPoint`.

**Adaptive navigation**

> Use `WindowClassBuilder`: bottom navigation bar on compact, navigation rail
> on medium, navigation drawer on expanded. Do not check device models or
> pixel widths.

**Tests for every foldable**

> Write a widget test that pumps `MyApp` on every `TwinDevicePreset` in
> closed, half-open and flat postures with `TwinSimulatedScreen.resolve`, and
> fails on any exception or overflow.

**Review an existing app**

> Review this app for foldable problems: content under the hinge, dialogs
> centred on the fold, layouts chosen by device model or exact width, and
> missing `TwinScreenScope`. Fix them with twin_screen.

## 4. Check the agent's work

You do not need a foldable to verify what the agent wrote:

1. **Run the tests it wrote**, especially the loop over every preset and
   posture. It is the fastest way to catch overflows and wrong panes.
2. **Open the fold simulator.** Run the app on any phone, emulator, desktop or
   browser, tap the round button of `TwinDebugOverlay`, turn on
   **Fold simulator** and go through the presets and postures. The panel shows
   the `mode` the code is reacting to, and the overlay draws the fold, so
   content under it is easy to spot.
3. **Use a foldable emulator** for the native side. Android Studio has Pixel
   Fold, 7.6" Fold-in and Resizable emulators. See [Platforms](platforms.md).

## 5. Mistakes agents make, and the fix

| What the agent writes | Why it breaks | Use instead |
|---|---|---|
| `TwinScreenScope` inside `MaterialApp`, or not at all | Dialogs, routes and overlays sit above the scope, so they miss the state and the iOS and web folds it writes into `MediaQuery` | Scope above `MaterialApp` |
| `if (deviceModel.contains('Fold'))` | Misses every other foldable, and the state changes as the device folds | `TwinScreen.modeOf(context)` |
| `if (MediaQuery.sizeOf(context).width > 700)` | Ignores the fold, and the numbers are arbitrary | `WindowClass.of(context)` or `WindowClassBuilder` |
| `Row(children: [Expanded(child: a), Expanded(child: b)])` on a spanned screen | The split misses the fold, and on Surface Duo content falls into the hinge gap | `TwinPane(start: a, end: b)` |
| `showDialog(...)` | The dialog lands right on the fold | `showFoldAwareDialog(...)` |
| `TwinScreen.of(context).mode` in a large widget | Rebuilds on every degree while the hinge moves | `TwinScreen.modeOf(context)` |
| `screen.hingeAngle!` | Null on most devices and platforms | Handle null, or use `posture` |
| left / right panes | Wrong in RTL languages and for horizontal folds | `start` / `end`, `TwinPaneSide` |
| A device that is open but `singlePane` treated as an error | The app is in split screen or on one panel; this is normal | Lay out as on a phone |
| Tests without `platformOverride` | The test talks to a platform channel with no native side, so the state arrives late | `TwinScreenScope(platformOverride: ...)` |

## 6. API at a glance

Everything below comes from `package:twin_screen/twin_screen.dart`.

| Need | API |
|---|---|
| Root widget | `TwinScreenScope({required child, breakpoints, injectDisplayFeatures = true, platformOverride})` |
| Whole state | `TwinScreen.of(context, [TwinAspect aspect])` → `TwinScreenData` |
| One part of the state | `TwinScreen.modeOf`, `deviceTypeOf`, `postureOf`, `isSpannedOf`, `hingeOf`, `hingeAngleOf`, `segmentsOf`, `breakpointsOf` |
| Hinge angle without rebuilds | `TwinScreen.hingeAngleStreamOf(context)` → `Stream<double?>` |
| Combined state | `TwinScreenMode { standard, cover, singlePane, dualPane, book, tabletop }`, `.isSpanned` |
| Hardware | `TwinDeviceType { standard, foldable, flip, dualScreen, unknown }`, `.isFoldable` |
| Hinge state | `TwinPosture { closed, halfOpened, flat, unknown }` |
| Fold geometry | `TwinHinge`: `bounds`, `axis`, `isSeparating`, `occludesContent`, `isPhysicalHinge` |
| Usable areas | `TwinScreenData.segments`, `startSegment`, `endSegment`, `segmentFor(TwinPaneSide)` |
| Two panes | `TwinPane({required start, required end, fallback = TwinPaneFallback.windowClass, fallbackRatio = 0.5})` |
| Will it split? | `TwinPaneRects.resolve(region:, hinge:, widthClass:, ...)`, `.isSplit`, `.start`, `.end` |
| Fallbacks | `TwinPaneFallback { windowClass, startOnly, endOnly, sideBySide, stacked }` |
| Dialog | `showFoldAwareDialog<T>({required context, required builder, anchorPoint, preferredSide = TwinPaneSide.start, allowSpanning = false, ...showDialog options})` |
| Placement for custom routes | `FoldAwareDialog({required child, anchorPoint, preferredSide, allowSpanning})`, `FoldAwareDialogRoute` |
| Window size class | `WindowClass.of(context)`: `.width`, `.height`, `.isCompact`, `.isMedium`, `.isExpanded`; classes compare with `<`, `>=` |
| Build per class | `WindowClassBuilder(compact:, medium:, expanded:)`, `WindowClassBuilder.custom(builder:)` |
| Breakpoints | `WindowClassBreakpoints({mediumWidth = 600, expandedWidth = 840, mediumHeight = 480, expandedHeight = 900})` |
| Debug overlay | `TwinDebugOverlay({required child, enabled = !kReleaseMode, controller, presets, drawFeatures = true, showPanel = true})` |
| Simulator from code | `TwinSimulatorController`: `simulate(preset:, posture:, orientation:, span:, hingeAngle:)`, `stop()` |
| Device presets | `TwinDevicePreset.iPhoneDuo`, `galaxyZFold`, `galaxyZFlip`, `pixelFold`, `surfaceDuo`, `xiaomiMixFlip`, `all` |
| Fake device in tests | `TwinSimulatedScreen.resolve(...)`, `TwinPlatformState`, `TwinScreenScope(platformOverride:)` |

The [API reference](https://pub.dev/documentation/twin_screen/latest/) has
every member.
