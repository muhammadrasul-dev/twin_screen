import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the iOS podspec version matches pubspec.yaml', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final String podspec = File('ios/twin_screen.podspec').readAsStringSync();
    final String? pubVersion = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);
    final String? podVersion = RegExp(r"s\.version\s*=\s*'([^']+)'").firstMatch(podspec)?.group(1);
    expect(pubVersion, isNotNull);
    expect(podVersion, pubVersion);
  });
}
