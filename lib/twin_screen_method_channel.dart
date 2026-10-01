/// The Android and iOS implementation of [TwinScreenPlatform].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'twin_screen_platform_interface.dart';

/// Talks to the Kotlin and Swift code over platform channels.
///
/// `getState` on [methodChannel] returns the current state; [eventChannel]
/// then streams every change. Where the native side is missing (unit tests,
/// unsupported platforms) it quietly reports [TwinPlatformState.fallback].
class MethodChannelTwinScreen extends TwinScreenPlatform {
  /// Creates the channel implementation.
  MethodChannelTwinScreen();

  /// The channel for one-off requests.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('twin_screen');

  /// The channel that streams state changes.
  @visibleForTesting
  final EventChannel eventChannel = const EventChannel('twin_screen/state');

  late final StreamController<TwinPlatformState> _controller =
      StreamController<TwinPlatformState>.broadcast(onListen: _start, onCancel: _stop);
  StreamSubscription<Object?>? _events;
  TwinPlatformState? _last;

  @override
  Stream<TwinPlatformState> watchState() async* {
    final TwinPlatformState? last = _last;
    if (last != null) yield last;
    yield* _controller.stream;
  }

  Future<void> _start() async {
    try {
      final Map<Object?, Object?>? map = await methodChannel.invokeMapMethod<Object?, Object?>(
        'getState',
      );
      _emit(map == null ? TwinPlatformState.fallback : TwinPlatformState.fromMap(map));
    } on MissingPluginException {
      _emit(TwinPlatformState.fallback);
      return;
    } on PlatformException {
      _emit(TwinPlatformState.fallback);
      return;
    }
    if (!_controller.hasListener || _events != null) return;
    _events = eventChannel.receiveBroadcastStream().listen(
      (Object? event) {
        if (event is Map<Object?, Object?>) _emit(TwinPlatformState.fromMap(event));
      },
      onError: (Object error) {
        debugPrint('twin_screen: native state stream failed: $error');
      },
    );
  }

  @override
  Future<void> rememberDeviceType(TwinDeviceType type) async {
    try {
      await methodChannel.invokeMethod<void>('rememberDeviceType', type.name);
    } on MissingPluginException {
      // No native side: nothing to remember.
    } on PlatformException catch (error) {
      debugPrint('twin_screen: could not remember the device type: $error');
    }
  }

  void _stop() {
    unawaited(_events?.cancel());
    _events = null;
  }

  void _emit(TwinPlatformState state) {
    if (state == _last) return;
    _last = state;
    if (_controller.hasListener) _controller.add(state);
  }
}
