import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twin_screen/twin_screen_method_channel.dart';
import 'package:twin_screen/twin_screen_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const MethodChannel methods = MethodChannel('twin_screen');
  const EventChannel events = EventChannel('twin_screen/state');

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(events, null);
  });

  test('the method channel is the default platform', () {
    expect(TwinScreenPlatform.instance, isA<MethodChannelTwinScreen>());
  });

  test('fromMap parses what the native side sends', () {
    final TwinPlatformState state = TwinPlatformState.fromMap(<Object?, Object?>{
      'deviceType': 'flip',
      'posture': 'halfOpened',
      'hingeAngle': 95,
      'rotation': 1,
      'features': <Object?>[
        <Object?, Object?>{
          'left': 0,
          'top': 503,
          'right': 411,
          'bottom': 503,
          'type': 'fold',
          'state': 'halfOpened',
        },
        <Object?, Object?>{
          'left': 190,
          'top': 10,
          'right': 220,
          'bottom': 40,
          'type': 'cutout',
          'state': 'unknown',
        },
        <Object?, Object?>{'left': 1},
      ],
    });
    expect(state.deviceType, TwinDeviceType.flip);
    expect(state.posture, TwinPosture.halfOpened);
    expect(state.hingeAngle, 95.0);
    expect(state.rotationQuarterTurns, 1);
    expect(state.source, TwinDataSource.plugin);
    expect(state.displayFeatures, hasLength(2));
    expect(state.displayFeatures.first.bounds, const Rect.fromLTRB(0, 503, 411, 503));
    expect(state.displayFeatures.first.state, DisplayFeatureState.postureHalfOpened);
    expect(state.displayFeatures.last.type, DisplayFeatureType.cutout);
  });

  test('fromMap tolerates unknown values', () {
    final TwinPlatformState state = TwinPlatformState.fromMap(<Object?, Object?>{
      'deviceType': 'rollable',
      'posture': 42,
    });
    expect(state.deviceType, TwinDeviceType.unknown);
    expect(state.posture, TwinPosture.unknown);
    expect(state.hingeAngle, isNull);
    expect(state.displayFeatures, isEmpty);
  });

  test('getState, then every event', () async {
    messenger.setMockMethodCallHandler(methods, (MethodCall call) async {
      expect(call.method, 'getState');
      return <Object?, Object?>{'deviceType': 'foldable', 'posture': 'closed', 'hingeAngle': 0};
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (Object? arguments, MockStreamHandlerEventSink sink) {
          sink.success(<Object?, Object?>{
            'deviceType': 'foldable',
            'posture': 'halfOpened',
            'hingeAngle': 90.0,
          });
        },
      ),
    );

    final List<TwinPlatformState> states = await MethodChannelTwinScreen()
        .watchState()
        .take(2)
        .toList();
    expect(states.map((TwinPlatformState s) => s.posture), <TwinPosture>[
      TwinPosture.closed,
      TwinPosture.halfOpened,
    ]);
    expect(states.last.hingeAngle, 90);
  });

  test('a missing native side reports an ordinary device', () async {
    final TwinPlatformState state = await MethodChannelTwinScreen().watchState().first;
    expect(state, TwinPlatformState.fallback);
    expect(state.deviceType, TwinDeviceType.standard);
  });

  test('rememberDeviceType sends the type name', () async {
    final List<MethodCall> calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(methods, (MethodCall call) async {
      calls.add(call);
      return null;
    });
    await MethodChannelTwinScreen().rememberDeviceType(TwinDeviceType.flip);
    expect(calls.single.method, 'rememberDeviceType');
    expect(calls.single.arguments, 'flip');
  });

  test('rememberDeviceType without a native side does not throw', () async {
    await MethodChannelTwinScreen().rememberDeviceType(TwinDeviceType.foldable);
  });
}
