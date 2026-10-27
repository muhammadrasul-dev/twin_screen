# Platforms

`twin_screen` has one Dart API, but each platform reports the hinge
differently. This guide explains what each one provides, how `twin_screen`
fills the gaps, and how to test on emulators and simulators.

| Platform | Fold bounds | Posture | Hinge angle | Cover screen | Device type |
|---|---|---|---|---|---|
| Android | Flutter (Jetpack WindowManager) | hinge sensor + fold state | `Sensor.TYPE_HINGE_ANGLE` | yes | sensor, fold axis and rotation |
| iOS 27.1+ (preview) | `UIView` reserved regions | `UIHinge.status` | `UIHinge.angle` | yes | `UIHingeInteraction` |
| Web | Viewport Segments API | Device Posture API | – | – | from segments |
| macOS, Windows, Linux | – | – | – | – | `standard` |

## How the pieces fit

```
platform (Kotlin / Swift / package:web)
   │  device type, posture, hinge angle, rotation, extra folds
   ▼
TwinScreenScope ── merges with Flutter's MediaQuery.displayFeatures
   │                (Flutter's folds win; nothing is duplicated)
   ├── writes the merged folds back into MediaQuery.displayFeatures
   └── provides TwinScreenData to TwinScreen.of(context)
```

Because the scope writes the folds into `MediaQuery.displayFeatures`,
Flutter's own fold-aware widgets (`DisplayFeatureSubScreen`,
`showDialog(anchorPoint:)`, `showMenu`, popup menus) see iOS and web folds as
well. If a future Flutter version reports display features on iOS itself
([flutter/flutter#193025](https://github.com/flutter/flutter/pull/193025)),
Flutter's features are used and the plugin's are dropped.

## Android

Flutter already reports folds through Jetpack WindowManager. `twin_screen`
leaves those untouched and adds what Flutter does not report:

- **Hardware check.** `Sensor.TYPE_HINGE_ANGLE` and
  `PackageManager.FEATURE_SENSOR_HINGE_ANGLE` (API 30+) tell whether the
  device has a hinge. Without one, the device is `standard`, unless a fold
  shows up in the window.
- **Hinge angle and posture.** The angle sensor is read while the app listens,
  at UI rate, and changes below one degree are skipped. Below 30° is
  `closed`, above 150° is `flat`.
- **Cover screen.** Android reports no fold on the cover screen, so Flutter
  alone cannot tell a closed foldable from an ordinary phone. The hinge sensor
  can: a closed hinge with no fold in the window is `cover`.
- **Book or flip.** The first time the app spans the fold, Dart combines the
  fold's axis with the display rotation (sent by the plugin) to find the axis
  in the device's natural orientation: vertical is a book foldable, horizontal
  a flip phone. The result is stored in `SharedPreferences`, so later launches
  know it at once, even on the cover screen. Before that, the plugin guesses
  from the shape of the open screen (flip phones open into a very tall screen;
  book foldables open close to square).
- **Surface Duo** is recognised by its model name and reported as
  `dualScreen`. Its hinge is reported by Flutter as a 34 dp-wide feature that
  hides content.

### Robustness rules

Android builds differ in how faithfully they report folds. `twin_screen`
applies these rules so that apps behave the same everywhere:

- **A flat fold yields to a half-open sensor.** Some builds keep reporting a
  flat fold while the device is bent. When the sensor clearly reads half-open,
  the posture is `halfOpened`, and the fold separates the window.
- **Thin features are not hinges.** A feature narrower than 1 logical pixel
  never hides content, even if the system calls it a hinge.
- **A fold the system did not report.** Some builds report no fold while the
  device lies flat. When the sensor says the device is open, the app fills the
  whole inner display and Flutter reports no fold, the plugin reports a fold at
  the centre of the display, along the hinge's natural axis. As soon as Flutter
  reports a fold, Flutter's is used instead.
- **A fold corrects a guess.** A fold seen in the window, together with the
  rotation, overrides the plugin's book-or-flip guess.

### Testing on Android emulators

Android Studio's Device Manager offers foldable emulators. Recommended:

| Emulator | Good for |
|---|---|
| **Pixel Fold** | The most faithful: reports flat and half-open folds, and has a real second display for the cover screen |
| **7.6" Fold-in with outer display** | Book foldable with a hinge sensor |
| **6.7" Horizontal Fold-in** | Flip phone, tabletop posture |
| **Resizable (Experimental)** | Switching between phone, foldable and tablet |

Control the hinge from the command line:

```sh
adb emu sensor set hinge-angle0 100   # half-open
adb emu sensor set hinge-angle0 180   # flat
adb emu fold                          # close (Pixel Fold moves the app to the cover display)
adb emu unfold
adb emu posture 2                     # 1 closed, 2 half-opened, 3 opened, 4 flipped, 5 tent
```

Or use **Extended controls → Virtual sensors → Hinge angle** in the emulator
window. Debug builds start slowly on emulators; a profile build
(`flutter run --profile`) is much quicker and still shows the debug overlay.

The generic 7.6" and 6.7" emulators report no fold while flat, and a 1-pixel
"hinge" in the flat state while bent. The robustness rules above handle both.

## iOS (iPhone Duo)

iOS 27.1 introduced `UIHingeInteraction` for iPhone Duo. `twin_screen` uses:

- `UIHingeInteraction(updateHandler:)` on the Flutter view. Each update carries
  a `UIHinge` (or nil when there is no hinge) with a `status` (closed,
  partially open, fully open) and an `angle` in radians, which is converted to
  degrees.
- `view.reservedRegions(kind: .division, options: .includeInactive)` for the
  fold rectangle, reported as a fold whose state follows the hinge status.
- `.occlusion` regions for the under-display camera, reported as a cutout.

Region frames are in points in the Flutter view's coordinate space, which are
Flutter's logical pixels.

**Built with any Xcode.** These APIs are reached through the Objective-C
runtime instead of the SDK headers. The plugin therefore compiles with Xcode
versions whose SDK predates iOS 27.1, and reports an ordinary device wherever
the API is missing at run time (older iOS, other iPhones, iPad).

**Status: preview.** Verified in the iOS 27.1 simulator: the hardware check, the
cover screen (`cover`, `closed`, 0°) and ordinary iPhones (`standard`). The open
and half-open states are implemented against the iOS 27.1 runtime but not yet
confirmed with an unfolded device.

**Geometry** (from the CoreSimulator profile): the inner display is
951 × 669 pt and folds like a book in landscape, so in portrait the fold runs
across (tabletop). On both displays the right 80 pt (in landscape) hold the
camera and the status bar, so apps get a 386 × 678 pt window on the cover
display and 871 × 669 pt inside. The fold stays at the middle of the whole
951 pt display, so it is 475.5 pt from the start of the window, not at the
window's centre (435.5 pt). The simulator's iPhone Duo preset models this.

**Deployment target.** Xcode 27 no longer builds for iOS 13 or 14, so the
plugin requires iOS 15.0. If your Podfile has an older `platform :ios`, raise
it, and if CocoaPods still complains about a pod's deployment target, add this
to the `post_install` block:

```ruby
target.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
end
```

**Simulator builds with Xcode 27.** `flutter build ios --simulator` fails with
"does not contain architectures" because Xcode 27's `lipo -verify_arch`
accepts one architecture only. This is a Flutter tool issue, not a
`twin_screen` one. `flutter run -d <simulator>` and device builds work.

## Web

- **Fold bounds** come from `window.viewport.segments` (Viewport Segments API).
  The gap between the first two segments becomes a fold (or a hinge-like gap,
  if the segments do not touch).
- **Posture** comes from `navigator.devicePosture.type`: `folded` is
  `halfOpened`, `continuous` is `flat` once a fold has been seen.
- **Device type** is `unknown` until a fold is seen, then `foldable`.
- Both APIs are feature-detected. Browsers without them report an ordinary
  window, and window classes still apply.

To test, use a Chromium-based browser that supports the Viewport Segments
API; its DevTools device toolbar includes foldable and dual-screen presets that
emulate the segments. The debug overlay's simulator works in every browser.

## Desktop and iPad

macOS, Windows and Linux report an ordinary device (pure Dart, no native code).
iPad reports an ordinary device through the iOS plugin. Window classes,
`TwinPane` fallbacks and the simulator work everywhere, so a desktop build is a
convenient place to design foldable layouts.
