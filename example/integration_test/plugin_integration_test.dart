// Runs on a real device or emulator, where the native side answers.
//
//   cd example && flutter test integration_test

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:twin_screen/twin_screen.dart';
import 'package:twin_screen/twin_screen_platform_interface.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the platform reports a state', (WidgetTester tester) async {
    final TwinPlatformState state = await TwinScreenPlatform.instance
        .watchState()
        .first;
    expect(state.deviceType, isNot(TwinDeviceType.unknown));
  });

  testWidgets('the scope resolves a mode', (WidgetTester tester) async {
    late TwinScreenData data;
    await tester.pumpWidget(
      TwinScreenScope(
        child: Builder(
          builder: (BuildContext context) {
            data = TwinScreen.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(TwinScreenMode.values, contains(data.mode));
  });
}
