import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/hmusic_audio_handler.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/features/settings/data/api_downloads_repository.dart';
import 'package:hmusic/features/settings/data/downloads_repository.dart';
import 'package:hmusic/features/settings/models/download_record.dart';
import 'package:hmusic/features/settings/view_models/auto_archive_view_model.dart';
import 'package:mocktail/mocktail.dart';

const HMusicTrack _track = HMusicTrack(
  id: 'wy-9',
  source: 'wy',
  sourceTrackId: '9',
  title: '晴天',
  artist: '周杰伦',
);

HMusicPlaybackState _playing({required String streamUrl}) =>
    HMusicPlaybackState(
      sessionId: 's',
      state: PlaybackStatus.playing,
      positionMs: 0,
      durationMs: 0,
      volume: 50,
      playMode: PlayMode.listLoop,
      queueIndex: 0,
      queueLength: 1,
      seekEnabled: true,
      updatedAt: 0,
      track: _track,
      streamUrl: streamUrl,
    );

class _MockHandler extends Mock implements HMusicAudioHandler {}

class _FakeDownloadsRepository implements DownloadsRepository {
  final List<HMusicTrack> started = <HMusicTrack>[];

  @override
  Future<void> start(HMusicTrack track, {String? quality}) async {
    started.add(track);
  }

  @override
  Future<List<DownloadRecord>> list() async => const <DownloadRecord>[];

  @override
  Future<void> remove(String id) async {}

  @override
  Future<void> retry(HMusicTrack track) async => start(track);
}

// 开关 + 一条播放状态流 → 看有没有发起入库。
Future<_FakeDownloadsRepository> _run({
  required bool enabled,
  required String streamUrl,
  int emits = 1,
}) async {
  final downloads = _FakeDownloadsRepository();
  final store = MemoryKeyValueStore();
  if (enabled) await store.setString('hmusic.downloads.autoArchive', '1');
  final controller = StreamController<HMusicPlaybackState>();
  final handler = _MockHandler();
  when(() => handler.serverStateStream).thenAnswer((_) => controller.stream);

  final container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      downloadsRepositoryProvider.overrideWithValue(downloads),
      hmusicAudioHandlerProvider.overrideWith((ref) async => handler),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(controller.close);

  container.read(autoArchiveEnabledProvider);
  container.read(autoArchiveWatcherProvider);
  // 开关读盘 + handler future 都在 microtask 上。
  await Future<void>.delayed(Duration.zero);
  for (var i = 0; i < emits; i += 1) {
    controller.add(_playing(streamUrl: streamUrl));
  }
  await Future<void>.delayed(Duration.zero);
  return downloads;
}

void main() {
  // 开关要能跨启动记住：只有 String/Double 两种存储口径，这里存 '1'/'0'。
  test('自动入库开关落盘并在下次启动读回', () async {
    final store = MemoryKeyValueStore();
    final first = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(first.dispose);

    expect(first.read(autoArchiveEnabledProvider), isFalse);
    await first.read(autoArchiveEnabledProvider.notifier).setEnabled(true);
    expect(await store.getString('hmusic.downloads.autoArchive'), '1');

    final second = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(second.dispose);
    second.read(autoArchiveEnabledProvider);
    await Future<void>.delayed(Duration.zero);
    expect(second.read(autoArchiveEnabledProvider), isTrue);
  });

  test('开关关着：播了也不下（默认不动服务器硬盘）', () async {
    final downloads = await _run(
      enabled: false,
      streamUrl: 'http://nas:6650/api/v1/proxy/audio/abc',
    );
    expect(downloads.started, isEmpty);
  });

  test('开着：在线歌播一首下一首，同一首只发一次', () async {
    final downloads = await _run(
      enabled: true,
      streamUrl: 'http://nas:6650/api/v1/proxy/audio/abc',
      emits: 3,
    );
    expect(downloads.started.single.sourceTrackId, '9');
  });

  test('开着但已经在放本地文件：曲库里已有，不重复下', () async {
    final downloads = await _run(
      enabled: true,
      streamUrl: 'http://nas:6650/api/v1/proxy/local/d1.sig',
    );
    expect(downloads.started, isEmpty);
  });
}
