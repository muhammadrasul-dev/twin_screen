import '../../twin_screen_platform_interface.dart';

/// The macOS, Windows and Linux implementation: an ordinary device.
///
/// Window classes, `TwinPane` fallbacks and the fold simulator still work.
class TwinScreenDesktop extends TwinScreenPlatform {
  /// Creates the desktop implementation.
  TwinScreenDesktop();

  /// Registers this class as the platform implementation. Called by the
  /// Flutter tool's generated plugin registrant.
  static void registerWith() {
    TwinScreenPlatform.instance = TwinScreenDesktop();
  }

  @override
  Stream<TwinPlatformState> watchState() =>
      Stream<TwinPlatformState>.value(TwinPlatformState.fallback);
}
