# FAQ and troubleshooting

## The mode is `standard` on my foldable

- **Is `TwinScreenScope` above your app?** Without it, `TwinScreen.of` reads
  `MediaQuery` only and cannot see the hinge sensor or the cover screen.
- **On the very first frame** the platform has not answered yet, so the
  device type is `unknown` and the mode `standard`. The correct state follows
  a moment later. Do not cache the first value.
- **On Android, does the device have a hinge sensor?** Devices without one
  (and Android before API 30) report `standard` until the app spans a fold.
  After that the type is remembered.
- **On iOS**, the hinge API needs iOS 27.1. Earlier versions report an
  ordinary device.

## The mode is `singlePane` although my app fills the open screen

`singlePane` means the device is open but no fold runs through the app window.
Usually this is correct: the app is in split screen or on one panel. If the
app does fill the screen, the system reported no fold. On Android
`twin_screen` assumes a centred fold in that case, as long as the app fills
the whole inner display. Please
[open an issue](https://github.com/muhammadrasul-dev/twin_screen/issues) with
your device model and the example app's "Screen state" page.

## TwinPane shows only one pane on an open Galaxy Z Flip

An open flip phone is a compact window (about 411 dp wide), and a flat fold
does not separate the screen, so the default fallback shows `start` only. Once
the phone is half-open (tabletop), the panes split at the fold. To always
show both panes, use `fallback: TwinPaneFallback.stacked`.

## My dialog still lands on the fold

`showDialog` without an `anchorPoint` is placed by Flutter. Use
`showFoldAwareDialog`, which falls back to `preferredSide` when there is no
anchor. Also check that `TwinScreenScope` is above `MaterialApp`, so the
dialog's route can see the fold.

## `hingeAngle` is always null

The platform has no hinge angle sensor: web, desktop, ordinary phones, Android
before API 30, iOS before 27.1. Use `posture` and `mode`, which work without
the angle wherever the platform reports a fold.

## The debug overlay is not there

It is off in release builds by default. Pass `enabled: true` to keep it. Also
make sure it is inside `TwinScreenScope` and above `MaterialApp`.

## The debug overlay covers my UI

Drag the round button or the panel by its header. Use `showPanel: false` to
hide it and drive the simulator from code, or `drawFeatures: false` to stop
drawing the fold outlines.

## Does it work with go_router, auto_route or nested navigators?

Yes. `TwinScreenScope` sits above the router, so every route sees the state.
`TwinPane` measures its own position, so it works inside any route or shell.
`showFoldAwareDialog` uses the root navigator by default; pass
`useRootNavigator: false` for a nested one.

## Does it drain the battery?

On Android the hinge sensor is read at UI rate only while the scope is alive,
and changes below one degree are dropped before they reach Dart. Widgets that
read the mode or posture do not rebuild while the angle moves. On iOS the hinge
interaction is event-driven.

## iOS build errors

- *"The iOS deployment target is set to 13.0"*: raise `platform :ios` in your
  Podfile to `15.0`. See [Platforms → iOS](platforms.md#ios-iphone-duo).
- *"does not contain architectures arm64 x86_64"* with
  `flutter build ios --simulator` on Xcode 27: a Flutter tool issue with
  Xcode 27's `lipo`. Use `flutter run -d <simulator>`.

## Can I test without a foldable?

Yes, in three ways: the [debug overlay's simulator](debug-overlay.md) on any
device, [widget tests](testing.md) with presets, and the Android Studio
foldable emulators described in [Platforms](platforms.md).

## Where do I report a device that behaves differently?

[Open an issue](https://github.com/muhammadrasul-dev/twin_screen/issues).
Include the device model, OS version, what you did (folded, rotated, split
screen) and a screenshot of the example app's "Screen state" page. That page
lists every value `twin_screen` computed, including the raw display features.
