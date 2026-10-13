## 0.1.0

First release.

* `TwinScreenScope` and `TwinScreen.of`: device type, posture, hinge angle,
  hinge bounds, segments, window class, data source and a combined `mode`
  (`standard`, `cover`, `singlePane`, `dualPane`, `book`, `tabletop`).
  Widgets can depend on one aspect only.
* `TwinScreen.hingeAngleStreamOf` for hinge angle updates without rebuilds.
* Fills `MediaQuery.displayFeatures` on iOS and web, so Flutter's own
  fold-aware widgets work there too. Folds Flutter already reports are kept.
* `TwinPane`: two panes split at the fold, with window-class fallbacks and RTL
  support.
* `showFoldAwareDialog` and `FoldAwareDialog`: dialogs on the side of the
  anchor point or `preferredSide`, optionally spanning both sides.
* `WindowClass`, `WindowClassBreakpoints` and `WindowClassBuilder`: Material 3
  window size classes with custom breakpoints.
* `TwinDebugOverlay`: draws segments, the hinge and cutouts, shows a draggable
  info panel, and simulates iPhone Duo, Galaxy Z Fold, Galaxy Z Flip, Pixel
  Fold, Surface Duo and Xiaomi Mix Flip. Off in release builds by default.
* Android: hinge sensor, posture and angle stream, cover-screen detection, book
  versus flip detection, and a remembered device type.
* iOS 27.1+ (preview): `UIHingeInteraction` and reserved regions, reached at
  run time so the plugin builds with any Xcode. The cover screen and the
  hardware check are verified in the simulator; the open and half-open states
  are not yet confirmed on an unfolded device. Requires iOS 15.0 or later.
* Web: Viewport Segments and Device Posture APIs.
* macOS, Windows and Linux: an ordinary device; window classes and the
  simulator still work.
* The app below the scope, and each `TwinPane` pane, keep their state when the
  device folds or unfolds.
* Guides in `doc/`, screenshots, and an example app covering every feature.
* A guide for AI coding agents (`doc/ai-agents.md`): a rules block to paste
  into `CLAUDE.md`, `AGENTS.md`, Cursor or Copilot instructions, prompts that
  work well, and the mistakes agents make most often.
* Requires Flutter 3.32 or later. Android: API 21+, with Android Gradle
  Plugin 8 or 9 (built-in Kotlin or the Kotlin plugin).
