# Contributing to twin_screen

Thanks for helping. The most valuable contributions are reports from real
devices, because foldables differ in subtle ways and no one owns them all.

## Reporting a device issue

Open an issue with:

1. the device model and OS version;
2. what you did (opened, folded, rotated, entered split screen);
3. what you expected and what happened;
4. a screenshot of the example app's **Screen state** page in that state. It
   shows every value `twin_screen` computed, including the raw display
   features Flutter reported.

## Development setup

```sh
git clone https://github.com/muhammadrasul-dev/twin_screen.git
cd twin_screen
flutter pub get
```

The package needs Flutter 3.32 or later.

### Project layout

```
lib/
  twin_screen.dart                   public API
  twin_screen_platform_interface.dart  platform interface (for tests and new platforms)
  twin_screen_method_channel.dart    Android and iOS channel
  twin_screen_web.dart               web implementation
  src/core/        TwinResolver: pure rules from raw input to TwinScreenData
  src/models/      enums, TwinHinge, TwinScreenData, WindowClass
  src/platform/    TwinPlatformState, desktop implementation
  src/widgets/     TwinScreenScope, TwinPane, FoldAwareDialog, WindowClassBuilder
  src/debug/       TwinDebugOverlay, simulator, device presets
android/           Kotlin: hinge sensor, posture, device type
ios/               Swift: UIHingeInteraction and reserved regions, through the runtime
example/           demo app for every feature
doc/               guides
```

Most rules live in `TwinResolver` as pure functions. When you change a rule,
add a test for it in `test/resolver_test.dart`.

## Checks

Run these before opening a pull request. CI runs the same.

```sh
dart format --set-exit-if-changed .
flutter analyze
flutter test
(cd example && flutter test)
dart pub publish --dry-run
```

Native code:

```sh
(cd example && flutter build apk --debug)
(cd example/android && ./gradlew :twin_screen:testDebugUnitTest)
(cd example && flutter build ios --no-codesign)
(cd example && flutter build web)
```

## Testing on emulators

See [doc/platforms.md](doc/platforms.md) for the Android foldable emulators,
the `adb emu` commands that move the hinge, and the iPhone Duo simulator.

## Style

- Follow the lints in `analysis_options.yaml`. Every public member needs a doc
  comment.
- Prefer small pure functions for rules, and widget tests for widgets.
- Keep the public API platform-neutral: a feature should work, or degrade
  gracefully, on every platform.
- Update `CHANGELOG.md` for user-visible changes.

## License

By contributing, you agree that your contributions are licensed under the MIT
license.
