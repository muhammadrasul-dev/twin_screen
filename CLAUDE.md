# twin_screen

Flutter plugin that gives foldable and dual-screen devices one API on every platform:
iPhone Duo (iOS 27.1), Android book foldables (Galaxy Z Fold, Pixel Fold, Xiaomi Mix Fold,
Honor Magic V, Surface Duo), Android flip phones (Galaxy Z Flip, Xiaomi Mix Flip, Moto Razr),
web (Viewport Segments API), and desktop/iPad as a graceful fallback.

Flutter itself only fills `MediaQuery.displayFeatures` on Android. iOS support is still an
open PR (flutter/flutter#193025). This package closes that gap and adds widgets on top.

Step-by-step execution order and progress checklist: `MVP_PLAN.md` (in Uzbek). Update its
checkboxes as phases complete.

## Working agreement

- The user (Muhammadrasul) writes in Uzbek. Reply in Uzbek (Latin script). Code, identifiers,
  dartdoc, README, CHANGELOG and commit messages stay in English (pub.dev audience).
- For every new feature or change request, ask clarifying questions first (AskUserQuestion),
  then implement, then ship it as a versioned update: bump `version`, add a CHANGELOG entry,
  keep `example/` and tests in sync.
- Build the MVP first. The user adds more widgets later, one request at a time.
- Get the user's go-ahead before creating the GitHub repo or publishing to pub.dev.

## Decisions (2026-09-25)

| Topic | Decision |
|---|---|
| Package name | `twin_screen` |
| Kind | Single (non-federated) plugin: Dart + Swift (iOS) + Kotlin (Android) + web (`package:web`). Desktop is pure Dart (`dartPluginClass`, no native code) |
| Org / Android package | `io.github.muhammadrasul_dev` |
| Publishing | Public GitHub `muhammadrasul-dev/twin_screen` + pub.dev, MIT license |
| Pane naming | `start` / `end`. Start is left in LTR, right in RTL, top on a horizontal hinge |
| Non-foldable fallback | Chosen by window class (compact shows start only; medium and expanded go side by side). The developer can override it |
| Window classes | Material 3, 3 classes: compact < 600, medium 600–839, expanded ≥ 840 (width). Height: compact < 480, medium 480–899, expanded ≥ 900. Breakpoints can be customized. large/extraLarge come later |
| Device check | Both the hardware check (is this a foldable?) and the live state (posture, spanned, hinge angle). See the state model below |
| FoldAwareDialog | Default side is the half that holds the `anchorPoint`. Without an anchor, use `preferredSide`. `allowSpanning` lets it cover both halves |
| Debug overlay | Hinge/segment drawing, info panel, fold simulator with device presets. Off in release builds by default. Other design choices are ours to make, aimed at what helps developers most |
| iOS SDK | The hinge API is called through the Objective-C runtime (no SDK headers needed), so the plugin compiles with any Xcode and reports `standard` where the API is missing at run time. iOS minimum is 15.0 (Xcode 27 refuses lower targets) |
| Test devices | None. Use Android Studio foldable emulators (Pixel Fold, 7.6" Fold-in with outer display, Resizable) and the package's own simulator |

## Device state model

The user wants every real-life state covered: both halves open, folded, a normal
(non-foldable) phone, and the app running on only one screen. The model uses separate
dimensions, plus one combined `mode` for convenience:

- `deviceType`: `standard` | `foldable` (book-style) | `flip` (horizontal fold) | `dualScreen`
  (two physical panels, e.g. Surface Duo) | `unknown`. Hardware fact, stable for the session.
- `posture`: `closed` | `halfOpened` | `flat` | `unknown`. Physical hinge state.
- `isSpanned`: whether the app window crosses the fold/hinge (two segments).
- `hinge`: bounds, axis (vertical/horizontal), `isSeparating`, `occludesContent`, or null.
- `hingeAngle`: degrees (0 = shut, 180 = flat), or null where the platform has no sensor.
- `segments`: logical rects of each usable region, in start→end order.
- `windowClass`: width class + height class.
- `mode` (derived):
  - `standard`: ordinary device (odatiy holat)
  - `cover`: foldable closed, app on the outer screen (buklangan / yopiq)
  - `singlePane`: device open, but the app occupies one side only (bitta ekranda), e.g. split-screen or one panel of a Duo
  - `dualPane`: spanned and flat (ikkala ekran ochiq)
  - `book`: spanned, half-opened, vertical hinge
  - `tabletop`: spanned, half-opened, horizontal hinge

## MVP features

1. **Detection & state**: `TwinScreenScope` (root widget) + `TwinScreen.of(context)` giving
   `TwinScreenData`. Use InheritedModel aspects so widgets rebuild only on what they read.
   `hingeAngle` is also available as a stream.
2. **Window classes**: `WindowClass.of(context)`, `WindowClassBuilder(compact:, medium:, expanded:)`,
   custom breakpoints on the scope.
3. **TwinPane**: `TwinPane(start:, end:, fallback:)`. If a hinge separates the halves, split
   exactly at the hinge and never put content under it. On a flat, non-separating fold, align
   the split to the fold when the window class is medium or larger. With no fold, follow the
   window-class fallback.
4. **FoldAwareDialog**: `showFoldAwareDialog(...)` + `FoldAwareDialog` widget. Placement rules
   as in the table above.
5. **Debug overlay**: `TwinDebugOverlay(child:)`. It draws segments, the hinge and reserved
   regions, and shows a draggable info panel (mode, posture, angle, window class, dp size,
   platform, data source). Its fold simulator offers presets (iPhone Duo, Galaxy Z Fold, Z Flip,
   Pixel Fold, Surface Duo, Xiaomi Mix Flip) and switches posture/orientation. The simulator
   renders the app at the preset's logical size and fakes the MediaQuery. It is the main way
   to test here, because the user has no foldable hardware.

## Architecture rule: MediaQuery injection

`TwinScreenScope` rewrites `MediaQuery.displayFeatures` from native iOS data, web segments or
the simulator. That way Flutter's own fold-aware widgets (`DisplayFeatureSubScreen`,
`showDialog(anchorPoint:)`, popup menus) also work on iOS/web, not just ours. If the platform
already reports display features (Android, or iOS once flutter#193025 lands), keep them and do
not duplicate.

## Platform implementation notes

- **Android**: Flutter already provides `displayFeatures` via Jetpack WindowManager. Kotlin adds
  the hardware check (`PackageManager.FEATURE_SENSOR_HINGE_ANGLE`, `Sensor.TYPE_HINGE_ANGLE` on
  API 30+) and the hinge angle stream, which lets us detect `closed` on the cover screen (no fold
  feature is reported there). Flip vs book comes from the fold axis relative to the natural
  orientation (Dart, using the rotation Kotlin sends); Dart sends the result back with
  `rememberDeviceType`, stored in SharedPreferences. Before that, Kotlin guesses from the open
  screen's aspect ratio. Robustness rules learned on emulators: a flat fold yields to a sensor
  that reads half-open; a feature thinner than 1 dp never occludes content; when the device is
  open, the app fills the whole inner display and Flutter reports no fold, Kotlin reports a fold
  at the display centre (Dart drops it as soon as Flutter reports one).
- **iOS 27.1**: `UIHingeInteraction(updateHandler:)` → `update.hinge?.status`
  (unknown 0 / closed 1 / partiallyOpen 2 / fullyOpen 3) and `hinge.angle` (radians; convert
  to degrees). `hinge == nil` means no hinge. `view.reservedRegions(kind: .division, options: .includeInactive)`
  gives the fold rect. `.occlusion` gives the under-display camera. Frames are in points, which
  equal Flutter logical pixels. Convert them into the FlutterView's coordinate space. Map:
  division → fold (partiallyOpen → halfOpened, fullyOpen → flat), occlusion → cutout.
  Verified in the iOS 27.1 simulator runtime (Objective-C introspection): the block passed to
  `initWithUpdateHandler:` receives **two** arguments, `(UIHingeInteraction, UIHingeInteractionUpdate)`;
  `UIHinge` has `status` (NSInteger) and `angle` (double); `UIViewReservedRegion` has `frame`,
  `kind`, `margins`, `isActive`; kinds come from `+[UIViewReservedRegionKind divisionRegionKind /
  occlusionRegionKind]`. Read properties only after `responds(to:)` (a KVC miss crashes the app).
  `includeInactive` is assumed to be `1 << 0`; still to be confirmed with an unfolded device.
  iPhone Duo geometry (CoreSimulator profile, @3x): cover display 466 × 678 pt, but the app window
  there is 386 × 678 pt (the right 80 pt hold the camera and status bar); inner display
  951 × 669 pt, folding like a book in landscape (so portrait gives a horizontal fold, tabletop).
- **Web**: `window.viewport.segments` (Viewport Segments API) + `navigator.devicePosture.type`
  (`continuous` / `folded`) via `package:web`. Feature-detect everything.
- **Desktop / iPad / other**: `deviceType = standard`. Window classes and fallbacks still apply.

## Environment

- Flutter SDK: `~/Desktop/Muhammadrasul/flutter` (3.44.6 stable, Dart 3.12.2).
- Xcode 27.0 (iOS 27.0 SDK, which has no hinge headers). Simulator runtimes: iOS 26.1, 27.0,
  27.1. The iPhone Duo simulator needs the 27.1 runtime (device UDID `C96F737C-…`). The hinge
  can't be moved from the command line; the cover state is what the simulator starts in.
- Xcode 27's `lipo -verify_arch` takes one arch only, which breaks `flutter build ios --simulator`
  (Flutter tool bug). Use `flutter run -d <simulator> --no-resident` instead. Device builds
  (`flutter build ios --no-codesign`) work.
- Android AVDs (API 36): `twin_pixel_fold` (accurate: reports flat and half-open folds, has a
  real second display for the cover screen; `adb emu fold` / `unfold`, `adb exec-out screencap -d
  <id>`), `twin_fold_in` (7.6" generic: no fold while flat, a 1 px "hinge" reported flat while
  bent, single display), `twin_flip` (6.7" horizontal). Set the angle with
  `adb emu sensor set hinge-angle0 <deg>`. Use `flutter build apk --profile` there; debug builds
  start very slowly on the emulator.
- Checks: `flutter analyze`, `flutter test`, `cd example && flutter test`,
  `cd example && flutter build apk --debug`, `flutter build ios --no-codesign`,
  `flutter build web`, `cd example/android && ./gradlew :twin_screen:testDebugUnitTest`,
  `dart pub publish --dry-run`.

## After the MVP

0.2.0 `showFoldAwareBottomSheet`, 0.3.0 `TwinListDetail` (+ `TwinPane.maintainHiddenPane`),
0.4.0 `TwinNavigation` are built and committed, not yet published (publish all at once, with the
user's go-ahead). Gotcha: `ModalBottomSheetRoute.buildPage` reads MediaQuery from the context it
is handed, so wrap `super.buildPage` in a `Builder` below `FoldAwareDialog`.

## Later (not in MVP)

large / extraLarge window classes, Android rear-display and dual-display modes
(`WindowAreaController`), hinge-angle driven animations, device model allowlists, keyboard shortcuts for the simulator.
