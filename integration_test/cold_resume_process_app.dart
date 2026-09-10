import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/core/audio/hmusic_audio_handler.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/features/player/data/api_lyric_repository.dart';
import 'package:hmusic/features/player/data/lyric_repository.dart';
import 'package:hmusic/features/player/models/hmusic_lyric.dart';
import 'package:hmusic/features/player/views/lyrics_page.dart';

import 'support/direct_audio_harness.dart';
import 'support/native_audio_probe.dart';
import 'support/native_test_report.dart';
import 'support/native_verification_store.dart';

// 用 flutter run/build 指定此入口；ready-to-terminate 后从外部终止，再启动同一个包。
// 每轮使用不同 HMUSIC_RESTART_RUN，正式 main 不引入此验证入口。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const report = NativeTestReport('process-resume');
  const fixture = String.fromEnvironment('HMUSIC_RESTART_FIXTURE');
  const runId = String.fromEnvironment(
    'HMUSIC_RESTART_RUN',
    defaultValue: 'manual',
  );
  final preferences = NativeVerificationStore(runId);
  final details = <String, Object?>{'pid': pid, 'runId': runId};
  try {
    final previousPid = await preferences.getString('preparedPid');
    final restarting = previousPid != null;
    details['previousPid'] = previousPid;
    final harness = DirectAudioHarness(
      preferences: preferences,
      duration: const Duration(seconds: 20),
      createPlayer: () =>
          ObservedAudioPlayer((error) => details['loadError'] = error),
      initialData: !restarting && fixture.isNotEmpty
          ? Map<String, String>.from(jsonDecode(fixture) as Map)
          : const {},
    );
    await harness.initialize();
    if (!restarting && fixture.isEmpty) {
      await harness.playback.playQueue([harness.track('restart')]);
      await harness.playback.reportLocal(state: 'paused', positionMs: 1000);
    }
    final saved = await harness.store.read('playback');
    final expectedPosition = (saved['positionMs'] as num).toInt();
    final handler = harness.handler;
    final notices = <String>[];
    handler.playbackNoticeStream.listen(notices.add);
    await handler.ensureServerState();
    details.addAll({
      'expectedPositionMs': expectedPosition,
      'restoredPositionMs': handler.effectivePosition.inMilliseconds,
      'trackId': handler.serverState?.track?.id,
      'initialPlaying': handler.player.playing,
      'sourceFixture': fixture.isNotEmpty,
    });
    if (handler.player.playing ||
        handler.effectivePosition.inMilliseconds != expectedPosition) {
      throw StateError('冷启动状态与磁盘快照不一致');
    }
    if (restarting && previousPid == '$pid') {
      throw StateError('未发生真实进程重启');
    }
    runApp(
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
    await report.write(restarting ? 'restored' : 'preparing', details);
    await WidgetsBinding.instance.endOfFrame;
    await handler.play();
    await _until(
      () async =>
          handler.player.playing &&
          handler.player.position.inMilliseconds > expectedPosition + 200,
    );
    if (restarting) {
      await handler.pause();
      details.addAll({
        'resumedPositionMs': handler.player.position.inMilliseconds,
        'nativeAudioResumed': true,
        'notices': notices,
      });
      await report.write('passed', details);
    } else {
      // 等正式 Handler 的周期回写真正进入平台存储，再让外部强制终止正在播放的进程。
      await _until(
        () async =>
            ((await harness.store.read('playback'))['positionMs'] as num) >
            expectedPosition,
      );
      await preferences.setString('preparedPid', '$pid');
      details['persistedPositionMs'] = (await harness.store.read(
        'playback',
      ))['positionMs'];
      details['playingBeforeTermination'] = handler.player.playing;
      await report.write('ready-to-terminate', details);
    }
  } catch (error) {
    details['errorType'] = error.runtimeType.toString();
    details['message'] = error.toString().replaceAll(
      RegExp(r'https?://\S+'),
      '<音频地址>',
    );
    await report.write('failed', details);
  }
}

Future<void> _until(Future<bool> Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (!await ready()) {
    if (DateTime.now().isAfter(deadline)) throw TimeoutException('原生播放未完成');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

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
