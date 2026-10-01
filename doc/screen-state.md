# Screen state

`TwinScreen.of(context)` returns a `TwinScreenData`: everything the package
knows about the device and how your app is shown. This guide explains each
part, how they combine into one `mode`, and how to read them without wasting
rebuilds.

## The model in one picture

A foldable can be in many real situations: open flat, half-open like a book,
standing like a laptop, folded with the app on the cover screen, or open with
the app sharing the screen with another app. An ordinary phone is just an
ordinary phone. `twin_screen` describes all of these with separate, independent
facts:

```
deviceType ── what the hardware is            (does not change)
posture ───── how the hinge is bent right now
isSpanned ─── whether the window crosses the fold
hinge ─────── where the fold is, and what kind
hingeAngle ── how far it is open, in degrees
segments ──── the usable rectangles
windowClass ─ how big the window is
          │
          ▼
mode ──────── one combined answer
```

## `mode`

`mode` is derived from the facts above. Use it for most layout decisions.

| `mode` | Device | Posture | Spanned | Fold axis |
|---|---|---|---|---|
| `standard` | ordinary | any | no | – |
| `cover` | foldable | closed | no | – |
| `singlePane` | foldable | flat or half-open | no | – |
| `dualPane` | any | flat | yes | any |
| `book` | any | half-open | yes | vertical |
| `tabletop` | any | half-open | yes | horizontal |

Two edge cases:

- When a foldable reports no posture (no hinge sensor), a compact window counts
  as `cover` and a wider one as `singlePane`.
- A window that crosses a fold is always spanned, even on a device the platform
  did not know was foldable. The device type is then worked out from the fold
  (see `deviceType` below).

`TwinScreenMode.isSpanned` tells you whether a mode spans the fold:

```dart
if (TwinScreen.modeOf(context).isSpanned) {
  // dualPane, book or tabletop
}
```

### Typical uses

| Mode | Idea |
|---|---|
| `tabletop` | Video, camera viewfinder or a game board on top, controls below |
| `book` | Two pages of a reader, or a list and its detail |
| `dualPane` | List and detail, or a wide canvas with tools on one side |
| `cover` | A compact layout, quick actions, glanceable content |
| `singlePane` | Behave like a phone; another app may be on the other side |
| `standard` | Your usual responsive layout (see [window classes](window-classes.md)) |

## `deviceType`

The hardware, as far as the platform can tell. It stays the same when the
device is folded, opened or rotated.

| Value | Hardware | Examples |
|---|---|---|
| `standard` | No fold | Most phones, tablets, desktops |
| `foldable` | Book-style: the fold is vertical in the natural orientation | Galaxy Z Fold, Pixel Fold, Honor Magic V, iPhone Duo |
| `flip` | Clamshell: the fold is horizontal in the natural orientation | Galaxy Z Flip, Xiaomi Mix Flip, Moto Razr |
| `dualScreen` | Two separate panels and a physical hinge | Surface Duo |
| `unknown` | The platform cannot tell yet | Web before any fold is seen |

`TwinScreenData.isFoldable` is true for `foldable`, `flip` and `dualScreen`.

How it is detected:

- **Android**: the hinge angle sensor says whether there is a hinge. The first
  time the app spans the fold, the fold's axis together with the display
  rotation tells book from flip, and the result is remembered across launches.
  Before that, the shape of the open screen is used (flip phones open into a
  very tall screen). Surface Duo is recognised by its model name.
- **iOS 27.1+**: `UIHingeInteraction` reports whether there is a hinge. iPhone
  Duo is a book-style foldable.
- **Web**: `unknown` until a fold is seen in the viewport segments, then
  `foldable`.

## `posture`

The physical state of the hinge right now.

| Value | Meaning |
|---|---|
| `closed` | Folded shut. On devices with a cover screen, the app runs there. |
| `halfOpened` | Partly open, like a laptop or a book held in two hands |
| `flat` | Fully open |
| `unknown` | No information, for example on devices without a hinge sensor |

On Android the posture comes from the hinge angle sensor: below 30° is closed,
above 150° is flat, and everything in between is half-open (the simulator uses
the same thresholds). On iOS it comes from `UIHinge.status`, and on web from
`navigator.devicePosture`. When the window spans a fold, the fold's
own state is combined with the sensor: a half-open fold wins, and a fold that
the system still reports as flat yields to a sensor that clearly reads
half-open.

## `isSpanned`, `hinge` and `segments`

`isSpanned` is true when a fold or hinge runs through the app window.
`hinge` then describes it:

| Field | Meaning |
|---|---|
| `bounds` | The rectangle of the fold, in logical pixels, in the window's coordinate space. A fold has zero width; a physical hinge has the width of the gap. |
| `axis` | `vertical` (splits left and right) or `horizontal` (splits top and bottom) |
| `isSeparating` | Whether the two sides should show separate content: true for a half-open fold and for any physical hinge |
| `occludesContent` | Whether content under `bounds` is invisible: true for a physical hinge at least 1 logical pixel wide |
| `isPhysicalHinge` | A hinge between two panels rather than a fold in one screen |
| `type`, `state` | The raw Flutter `DisplayFeatureType` and `DisplayFeatureState` |

`segments` lists the usable rectangles, with the area under the hinge left
out:

```dart
final screen = TwinScreen.of(context);

screen.segments;     // one rect when not spanned, two when spanned
screen.startSegment; // leading side
screen.endSegment;   // trailing side (same as startSegment when not spanned)
screen.segmentFor(TwinPaneSide.end);
```

Segments are ordered for the current text direction: in a right-to-left
locale the right side comes first. For a horizontal fold, the top side is
always first.

## `hingeAngle`

The hinge angle in degrees, from 0 (shut) to 180 (flat), or null where there
is no sensor (web, desktop, ordinary phones). It is available on Android
devices with a hinge sensor and on iOS 27.1+.

To react to the angle continuously (an animation that follows the hinge),
listen to the stream instead of rebuilding:

```dart
StreamBuilder<double?>(
  stream: TwinScreen.hingeAngleStreamOf(context),
  builder: (context, snapshot) {
    final angle = snapshot.data ?? 180;
    return Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.rotationX((180 - angle) * math.pi / 360),
      child: const Lid(),
    );
  },
)
```

The stream emits the current value first, then every change. On Android,
changes smaller than one degree are skipped unless they cross a posture
boundary.

## `windowClass` and `size`

`windowClass` is the Material 3 size class of the app window, and `size` is
the window size in logical pixels. See [window classes](window-classes.md).

## `source`

Where the fold information came from. Useful when debugging:

| Value | Meaning |
|---|---|
| `flutter` | Flutter reported the fold itself (Android) |
| `plugin` | `twin_screen` read it from the platform (iOS, web, or the hinge sensor) |
| `simulator` | The fold simulator or a test override |
| `fallback` | No fold information is available on this platform |

## Reading the state efficiently

`TwinScreen.of(context)` makes your widget depend on the whole state, so it
rebuilds when anything changes, including every degree of hinge movement.
Read only what you need:

```dart
TwinScreen.modeOf(context);       // TwinScreenMode
TwinScreen.deviceTypeOf(context); // TwinDeviceType
TwinScreen.postureOf(context);    // TwinPosture
TwinScreen.isSpannedOf(context);  // bool
TwinScreen.hingeOf(context);      // TwinHinge?
TwinScreen.hingeAngleOf(context); // double?
TwinScreen.segmentsOf(context);   // List<Rect>
WindowClass.of(context);          // WindowClass
```

Each of these rebuilds the caller only when that part changes. Under the hood
`TwinScreenScope` is an `InheritedModel`. You can also pass an aspect to
`of`:

```dart
final data = TwinScreen.of(context, TwinAspect.segments);
```

`TwinScreen.maybeOf` returns null when there is no scope.

## Without a scope

`TwinScreen.of` also works without a `TwinScreenScope`. It then reads
`MediaQuery` alone, so it sees Android folds that Flutter reports, but not iOS
or web folds, the hinge sensor or the cover-screen state. Use a scope in real
apps.

## Nested scopes

A `TwinScreenScope` inside another one does not listen to the platform again.
It passes the outer state through, applying its own `breakpoints` if they
differ. Use this to give one part of your app different window-class
breakpoints.

## The scope's options

```dart
TwinScreenScope(
  breakpoints: WindowClassBreakpoints.material3, // window class breakpoints
  injectDisplayFeatures: true,                   // write folds into MediaQuery
  platformOverride: null,                        // fake platform report (tests)
  child: MyApp(),
)
```

Set `injectDisplayFeatures: false` if you do not want `twin_screen` to change
`MediaQuery.displayFeatures` for the widgets below.
