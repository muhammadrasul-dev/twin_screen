/// Fold-aware and dual-screen layouts for Flutter.
///
/// Wrap the app in [TwinScreenScope], then read [TwinScreen.of] or use
/// [TwinPane], [WindowClassBuilder] and [showFoldAwareDialog]. Add
/// [TwinDebugOverlay] to see the fold and simulate foldable devices.
library;

export 'src/core/twin_resolver.dart';
export 'src/debug/twin_debug_overlay.dart';
export 'src/debug/twin_device_preset.dart';
export 'src/debug/twin_simulator.dart';
export 'src/models/twin_enums.dart';
export 'src/models/twin_hinge.dart';
export 'src/models/twin_screen_data.dart';
export 'src/models/window_class.dart';
export 'src/platform/twin_platform_state.dart';
export 'src/widgets/fold_aware_dialog.dart';
export 'src/widgets/twin_pane.dart';
export 'src/widgets/twin_screen_scope.dart';
export 'src/widgets/window_class_builder.dart';
