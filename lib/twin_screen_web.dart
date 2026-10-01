/// The web implementation of [TwinScreenPlatform].
///
/// Reads the fold from the Viewport Segments API (`window.viewport.segments`)
/// and the posture from the Device Posture API (`navigator.devicePosture`).
/// Both are feature-detected; browsers without them report an ordinary
/// window.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType, Rect;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'twin_screen_platform_interface.dart';

/// Web implementation of [TwinScreenPlatform].
class TwinScreenWeb extends TwinScreenPlatform {
  /// Creates the web implementation.
  TwinScreenWeb();

  /// Registers this class as the platform implementation.
  static void registerWith(Registrar registrar) {
    TwinScreenPlatform.instance = TwinScreenWeb();
  }

  late final StreamController<TwinPlatformState> _controller =
      StreamController<TwinPlatformState>.broadcast(onListen: _start, onCancel: _stop);
  TwinPlatformState? _last;
  JSFunction? _onChange;
  bool _sawFold = false;

  @override
  Stream<TwinPlatformState> watchState() async* {
    final TwinPlatformState? last = _last;
    if (last != null) yield last;
    yield* _controller.stream;
  }

  void _start() {
    final JSFunction onChange = ((web.Event _) => _update()).toJS;
    _onChange = onChange;
    web.window.addEventListener('resize', onChange);
    _devicePosture?.addEventListener('change', onChange);
    _update();
  }

  void _stop() {
    final JSFunction? onChange = _onChange;
    if (onChange == null) return;
    web.window.removeEventListener('resize', onChange);
    _devicePosture?.removeEventListener('change', onChange);
    _onChange = null;
  }

  void _update() {
    final String? postureType = _devicePosture?.type;
    final bool folded = postureType == 'folded';
    final List<web.DOMRect> segments = _viewport?.segments?.toDart ?? const <web.DOMRect>[];
    final DisplayFeature? fold = _foldBetween(segments, folded);
    if (fold != null || folded) _sawFold = true;

    final TwinPlatformState state = TwinPlatformState(
      deviceType: _sawFold ? TwinDeviceType.foldable : TwinDeviceType.unknown,
      posture: folded
          ? TwinPosture.halfOpened
          : (_sawFold && postureType == 'continuous' ? TwinPosture.flat : TwinPosture.unknown),
      displayFeatures: fold == null ? const <DisplayFeature>[] : <DisplayFeature>[fold],
      source: TwinDataSource.plugin,
    );
    if (state == _last) return;
    _last = state;
    if (_controller.hasListener) _controller.add(state);
  }
}

/// Builds the fold that sits between the first two viewport segments.
DisplayFeature? _foldBetween(List<web.DOMRect> segments, bool folded) {
  if (segments.length < 2) return null;
  final List<web.DOMRect> sorted = segments.toList()
    ..sort((web.DOMRect a, web.DOMRect b) {
      final int byTop = a.top.compareTo(b.top);
      return byTop != 0 ? byTop : a.left.compareTo(b.left);
    });
  final web.DOMRect first = sorted[0];
  final web.DOMRect second = sorted[1];
  final bool sideBySide = second.left >= first.right - 1;
  final Rect bounds = sideBySide
      ? Rect.fromLTRB(
          first.right,
          math.min(first.top, second.top),
          math.max(first.right, second.left),
          math.max(first.bottom, second.bottom),
        )
      : Rect.fromLTRB(
          math.min(first.left, second.left),
          first.bottom,
          math.max(first.right, second.right),
          math.max(first.bottom, second.top),
        );
  return DisplayFeature(
    bounds: bounds,
    type: DisplayFeatureType.fold,
    state: folded ? DisplayFeatureState.postureHalfOpened : DisplayFeatureState.postureFlat,
  );
}

@JS('viewport')
external _Viewport? get _viewport;

@JS('navigator.devicePosture')
external _DevicePosture? get _devicePosture;

extension type _Viewport._(JSObject _) implements JSObject {
  external JSArray<web.DOMRect>? get segments;
}

extension type _DevicePosture._(JSObject _) implements web.EventTarget {
  external String get type;
}
