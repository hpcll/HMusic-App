import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/core/audio/hmusic_audio_handler.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/features/player/data/api_lyric_repository.dart';
import 'package:hmusic/features/player/data/lyric_repository.dart';
import 'package:hmusic/features/player/models/hmusic_lyric.dart';
import 'package:hmusic/features/player/views/lyrics_page.dart';
import 'package:integration_test/integration_test.dart';

import 'support/direct_audio_harness.dart';
import 'support/native_audio_probe.dart';
import 'support/native_test_report.dart';
import 'support/verification_harness.dart';

class _Lyrics implements LyricRepository {
  @override
  Future<HMusicLyric> fetchLyric(HMusicTrack track) async => const HMusicLyric(
    lines: [
      LyricLine(timeMs: 0, text: '回到上次听到的地方'),
      LyricLine(timeMs: 1000, text: '继续播放，歌词随音乐前行'),
      LyricLine(timeMs: 97350, text: '每一段旋律都有自己的回忆'),
      LyricLine(timeMs: 110000, text: '下一句，仍然在这里'),
    ],
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const report = NativeTestReport('cold-resume-and-lyrics');
  const fixture = String.fromEnvironment('HMUSIC_RESTART_FIXTURE');
  final details = <String, Object?>{'savedSourceProbe': fixture.isNotEmpty};
  unawaited(
    binding.allTestsPassed.future.then(
      (passed) => report.write(passed ? 'passed' : 'failed', {
        ...details,
        'failures': binding.failureMethodsDetails
            .map((e) => e.toString())
            .toList(),
      }),
    ),
  );

  testWidgets('冷启动快照从歌词页恢复真实原生音频', (tester) async {
    await report.write('started', details);
    final harness = DirectAudioHarness(
      createPlayer: () =>
          ObservedAudioPlayer((error) => details['loadError'] = error),
      initialData: fixture.isEmpty
          ? const {}
          : Map<String, String>.from(jsonDecode(fixture) as Map),
    );
    addTearDown(harness.dispose);
    await harness.initialize();
    if (fixture.isEmpty) {
      await harness.playback.playQueue([harness.track('A')]);
      await harness.playback.reportLocal(state: 'paused', positionMs: 1000);
      await harness.playback.close();
      harness.sources.close();
    }
    final handler = harness.handler;
    final notices = <String>[];
    final noticeSubscription = handler.playbackNoticeStream.listen((message) {
      notices.add(message.replaceAll(RegExp(r'https?://\S+'), '<音频地址>'));
    });
    addTearDown(noticeSubscription.cancel);
    await handler.ensureServerState();
    final savedPosition = handler.serverState!.positionMs;
    expect(handler.player.playing, isFalse);
    expect(handler.effectivePosition.inMilliseconds, savedPosition);
    details['restoredPositionMs'] = savedPosition;
    await report.write('restored', details);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hmusicAudioHandlerProvider.overrideWith((ref) async => handler),
          lyricRepositoryProvider.overrideWithValue(_Lyrics()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HMusicTheme.light(),
          home: const LyricsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await File(
      '${NativeTestReport.outputDirectory}/hmusic-lyrics-restored.png',
    ).writeAsBytes(
      await binding.takeScreenshot('lyrics-restored'),
      flush: true,
    );
    expect(find.byTooltip('播放').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('播放'));
    await tester.pump();
    await report.write('resuming', details);
    try {
      await pumpUntil(
        tester,
        _until(() {
          if (notices.isNotEmpty) fail('续播返回错误：${notices.last}');
          return handler.player.playing &&
              handler.player.position.inMilliseconds > savedPosition + 100;
        }),
        timeout: const Duration(seconds: 75),
      );
    } finally {
      details['nativeState'] = {
        'playing': handler.player.playing,
        'positionMs': handler.player.position.inMilliseconds,
        'processing': handler.player.processingState.name,
        'status': handler.serverState?.state.name,
        'hasStream': handler.serverState?.streamUrl != null,
        'sourceStatus': harness.sources.health.values.toList(),
        'notices': notices,
      };
      await report.write('native-state', details);
      if (handler.serverState?.streamUrl case final stream?) {
        details['streamProbe'] = await probeNativeStream(stream);
      }
    }
    await tester.pump();
    expect(find.byTooltip('暂停').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('暂停'));
    await pumpUntil(tester, _until(() => !handler.player.playing));
    await tester.pumpAndSettle();
    expect(handler.player.position.inMilliseconds, greaterThan(savedPosition));
    details['nativeAudioResumed'] = true;
    details['pauseFromLyricsWorked'] = true;
    await File(
      '${NativeTestReport.outputDirectory}/hmusic-lyrics-after-resume.png',
    ).writeAsBytes(
      await binding.takeScreenshot('lyrics-after-resume'),
      flush: true,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _until(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 70));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('原生播放状态未完成');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
