import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:integration_test/integration_test.dart';

import 'support/direct_audio_harness.dart';
import 'support/native_test_report.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const report = NativeTestReport('direct-audio');
  // AOT 真机运行也可从设备控制台确认完整测试结果，无需依赖无线 VM 自动发现。
  unawaited(
    binding.allTestsPassed.future.then((passed) async {
      debugPrint('HMUSIC_DIRECT_AUDIO_RESULT=${passed ? 'PASS' : 'FAIL'}');
      await report.write(
        passed ? 'passed' : 'failed',
        binding.failureMethodsDetails
            .map((failure) => failure.toString())
            .toList(),
      );
    }),
  );
  testWidgets('native direct LX -> proxy -> audio service -> pause/seek/next', (
    tester,
  ) async {
    await report.write('started');
    final harness = DirectAudioHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('HMusic 直连音频真机验证'))),
      ),
    );
    await harness.initialize();
    await report.write('initialized');
    final handler = harness.handler;
    await handler.executePlayback(
      () =>
          harness.playback.playQueue([harness.track('A'), harness.track('B')]),
    );
    await _until(
      () =>
          handler.player.playing &&
          handler.player.position.inMilliseconds > 200,
    );
    expect(harness.requests, greaterThan(0));
    expect(handler.serverState?.streamUrl, startsWith('http://127.0.0.1:'));
    expect(handler.mediaItem.valueOrNull?.title, '直连集成测试 A');
    await report.write('playing_a');
    await handler.pause();
    expect(handler.player.playing, isFalse);
    await handler.seek(const Duration(seconds: 1));
    expect(handler.player.position.inMilliseconds, greaterThanOrEqualTo(900));
    await handler.play();
    await _until(() => handler.serverState?.track?.id == 'wy:fixture-B');
    await _until(
      () =>
          handler.player.playing &&
          handler.player.position.inMilliseconds > 100,
    );
    expect(handler.serverState?.queueIndex, 1);
    expect(handler.mediaItem.valueOrNull?.title, '直连集成测试 B');
    await report.write('playing_b_after_pause_seek_next');
    await handler.setPlayMode(PlayMode.singleLoop);
    await handler.seek(const Duration(milliseconds: 3500));
    await _until(() => handler.player.position.inMilliseconds < 1000);
    expect(handler.serverState?.track?.id, 'wy:fixture-B');
    expect(handler.player.playing, isTrue);
    await report.write('single_loop_passed');
    await handler.transitionBackend(() async {});
    expect(handler.player.playing, isFalse);
    expect(handler.serverState, isNull);
  });
}

Future<void> _until(bool Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) fail('原生音频状态未在 20 秒内满足预期');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
