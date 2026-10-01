# Getting started

This guide adds `twin_screen` to an app and makes one screen fold-aware. It
takes about five minutes, and you do not need a foldable device.

## 1. Add the package

```sh
flutter pub add twin_screen
```

The package needs Flutter 3.32 or later. On iOS, the app must target iOS 15.0
or later. In `ios/Podfile`:

```ruby
platform :ios, '15.0'
```

No permissions, keys or manifest entries are needed on any platform.

## 2. Wrap your app

`TwinScreenScope` listens to the platform and provides the screen state to
every widget below it. Put it above `MaterialApp` (or `CupertinoApp`,
`WidgetsApp`), so that every route, dialog and overlay can see it:

```dart
import 'package:flutter/material.dart';
import 'package:twin_screen/twin_screen.dart';

void main() {
  runApp(
    const TwinScreenScope(
      child: TwinDebugOverlay(child: MyApp()),
    ),
  );
}
```

`TwinDebugOverlay` is optional, but very useful while developing. It adds a
small round button that shows the current state and lets you simulate
foldable devices. It removes itself in release builds, so you can leave it in
place.

> **Why above `MaterialApp`?** The scope also writes the fold into
> `MediaQuery.displayFeatures` on iOS and web. Widgets inside `MaterialApp`
> (including Flutter's own `showDialog`) read that value, so the scope must
> sit above them.

## 3. Read the state

Anywhere below the scope:

```dart
final screen = TwinScreen.of(context);

Text('mode: ${screen.mode.name}, posture: ${screen.posture.name}');
```

The [screen state guide](screen-state.md) explains every field.

## 4. Split a screen at the fold

Replace a single-pane body with `TwinPane`:

```dart
class MailPage extends StatefulWidget {
  const MailPage({super.key});

  @override
  State<MailPage> createState() => _MailPageState();
}

class _MailPageState extends State<MailPage> {
  Mail? _open;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mail')),
      body: TwinPane(
        start: MailList(onOpen: (mail) => setState(() => _open = mail)),
        end: _open == null ? const NoMailSelected() : MailView(mail: _open!),
      ),
    );
  }
}
```

What happens now:

- **Ordinary phone, cover screen, split screen**: only the list is shown.
- **Unfolded foldable, tablet, desktop**: the list and the message are shown
  side by side, split exactly at the fold when there is one.
- **Half-open flip phone (tabletop)**: the list is on top and the message
  below the fold.

When the panes are not split, open the detail as a new page instead. You can
ask `TwinPaneRects` whether `TwinPane` would split:

```dart
final screen = TwinScreen.of(context);
final split = TwinPaneRects.resolve(
  region: Offset.zero & screen.size,
  hinge: screen.hinge,
  widthClass: screen.windowClass.width,
).isSplit;

void open(Mail mail) {
  if (split) {
    setState(() => _open = mail);
  } else {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MailView(mail: mail)));
  }
}
```

## 5. Try it without a foldable

Run the app on any phone, simulator, desktop or browser. Tap the round button
of the debug overlay, turn on **Fold simulator**, and pick a device:

- **Galaxy Z Fold, half-open**: the panes split at the fold (`book`).
- **Galaxy Z Flip, half-open**: list on top, detail below (`tabletop`).
- **Any foldable, closed**: the app moves to the cover screen (`cover`).

See the [debug overlay guide](debug-overlay.md) for everything the simulator
can do.

## Next steps

- Keep dialogs off the hinge with [`showFoldAwareDialog`](fold-aware-dialog.md).
- Use [window classes](window-classes.md) for navigation that adapts to every
  screen size.
- Write [widget tests](testing.md) for your fold-aware layouts.
