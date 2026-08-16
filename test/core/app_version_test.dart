import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/app_version.dart';

void main() {
  test('kAppVersion 与 pubspec.yaml 的 version 一致', () {
    // 机械校验防两处漂移：发版改 pubspec 忘改常量会在这里直接红。
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml 里找不到 version');
    expect(kAppVersion, match!.group(1));
  });
}
