/// The platform layer of `twin_screen`.
///
/// Most apps never need this library. Import it to replace the platform in
/// tests or to add support for another platform.
library;

import 'src/models/twin_enums.dart';
import 'src/platform/twin_platform_state.dart';
import 'twin_screen_method_channel.dart';

export 'src/models/twin_enums.dart' show TwinDataSource, TwinDeviceType, TwinPosture;
export 'src/platform/twin_platform_state.dart';

/// Reports hinge and fold information from the host platform.
///
/// Android and iOS use [MethodChannelTwinScreen], web uses `TwinScreenWeb`,
/// and desktop reports an ordinary device.
abstract class TwinScreenPlatform {
  /// Creates a platform implementation.
  TwinScreenPlatform();

  /// The implementation in use. Defaults to [MethodChannelTwinScreen].
  ///
  /// Assign a fake to replace the platform, for example in tests.
  static TwinScreenPlatform instance = MethodChannelTwinScreen();

  /// Emits the current state as soon as it is known, then every change.
  ///
  /// Several listeners may subscribe at once. Platforms without native
  /// support emit [TwinPlatformState.fallback].
  Stream<TwinPlatformState> watchState();

  /// Tells the platform which hardware type a fold revealed, so it can report
  /// it on later launches before any fold is visible (for example on the
  /// cover screen). The default does nothing.
  Future<void> rememberDeviceType(TwinDeviceType type) async {}
}
