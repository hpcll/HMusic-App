import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/music/direct_playlist_importer.dart';
import 'package:hmusic/core/direct/storage/direct_local_store.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/queue/direct_queue_repository.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/features/playlists/data/direct_playlists_repository.dart';
import 'package:hmusic/features/stats/data/direct_stats_repository.dart';

import 'support/direct_fixture.dart';

class _Importer extends Fake implements DirectPlaylistImporter {
  @override
  Future<ImportedDirectPlaylist> import(String text) async =>
      ImportedDirectPlaylist('导入测试', [
        directTrack('1'),
        directTrack('1'),
        directTrack('2'),
      ], 8);
}

void main() {
  test(
    'concurrent queue writes survive recreation without overwriting Server keys',
    () async {
      final preferences = MemoryKeyValueStore();
      await preferences.setString(
        'hmusic.serverBase',
        'https://server.example',
      );
      final store = DirectLocalStore(preferences),
          queue = DirectQueueRepository(DirectLocalStore(preferences));
      await Future.wait([
        for (var i = 0; i < 30; i++) queue.addTrack(directTrack('$i')),
      ]);
      final restored = await DirectQueueRepository(store).getQueue();
      expect(restored.items, hasLength(30));
      expect(restored.items.map((item) => item.id).toSet(), hasLength(30));
      expect(
        await preferences.getString('hmusic.serverBase'),
        'https://server.example',
      );
    },
  );

  test(
    'corrupt local data is surfaced and remains intact after failed edit',
    () async {
      final preferences = MemoryKeyValueStore();
      await preferences.setString('hmusic.direct.v1.queue', '{broken');
      final queue = DirectQueueRepository(DirectLocalStore(preferences));
      await expectLater(
        queue.addTrack(directTrack('1')),
        throwsA(isA<ApiFailure>()),
      );
      expect(await preferences.getString('hmusic.direct.v1.queue'), '{broken');
      await preferences.setString('hmusic.direct.v1.queue', '{}');
      expect((await queue.addTrack(directTrack('2'))).items, hasLength(1));
    },
  );

  test(
    'playlists persist atomic additions, deduplicate imports and normalize positions',
    () async {
      final f = DirectFixture();
      addTearDown(f.dispose);
      final playlists = DirectPlaylistsRepository(
        f.store,
        _Importer(),
        f.playback,
      );
      final created = await playlists.createPlaylist('收藏');
      await Future.wait([
        for (var i = 0; i < 15; i++)
          playlists.addTrack(created.id, directTrack('$i')),
      ]);
      var detail = await playlists.getPlaylist(created.id);
      expect(detail.items, hasLength(15));
      await playlists.removeItem(created.id, detail.items[2].id);
      detail = await playlists.getPlaylist(created.id);
      expect(
        detail.items.map((item) => item.position),
        orderedEquals(List.generate(14, (i) => i)),
      );
      final result = await playlists.importPlaylist(
        'https://music.163.com/playlist?id=1',
      );
      expect(result.imported, 2);
      expect(result.skipDuplicate, 1);
      expect(result.skipTruncated, 5);
      expect((await playlists.getPlaylists()).length, 2);
    },
  );

  test(
    'listening statistics record confirmed local starts once, not pause/resume or failures',
    () async {
      final f = DirectFixture();
      addTearDown(f.dispose);
      await f.init();
      await f.playback.playTrack(directTrack('1'));
      final stats = DirectStatsRepository(f.store, now: () => f.now);
      expect((await stats.getStats()).overview.totalPlays, 0);
      await f.playback.reportLocal(state: 'playing', positionMs: 3000);
      await f.playback.pause();
      await f.playback.resume();
      await f.playback.reportLocal(state: 'playing', positionMs: 6000);
      await f.playback.playTrack(directTrack('2'));
      await f.playback.reportLocal(state: 'playing');
      final result = await stats.getStats();
      expect(result.overview.totalPlays, 2);
      expect(result.overview.uniqueTracks, 2);
      expect(result.last30d.totalPlays, 2);
      expect(result.dailyTrend.last.count, 2);
      expect(
        jsonEncode(await f.store.read('history')),
        isNot(contains('fixture-token')),
      );
    },
  );
}
