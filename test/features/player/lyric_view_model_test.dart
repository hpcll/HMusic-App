import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/playback_state_update.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/features/player/data/api_lyric_repository.dart';
import 'package:hmusic/features/player/data/lyric_repository.dart';
import 'package:hmusic/features/player/models/hmusic_lyric.dart';
import 'package:hmusic/features/player/view_models/lyric_view_model.dart';
import 'package:hmusic/features/player/view_models/player_view_model.dart';

import 'support/playback_ui_fixture.dart';

class _Lyrics implements LyricRepository {
  final requests = <String>[];
  final pending = <String, Completer<HMusicLyric>>{};

  @override
  Future<HMusicLyric> fetchLyric(HMusicTrack track) {
    requests.add(track.id);
    return pending.putIfAbsent(track.id, Completer.new).future;
  }
}

void main() {
  test('歌词直接订阅播放曲目，切歌后拒绝迟到结果且同曲不重复请求', () async {
    final handler = UiAudioHandler(uiPlayback());
    final repository = _Lyrics();
    final container = ProviderContainer(
      overrides: [
        serverPlaybackStateProvider.overrideWith((ref) async* {
          yield handler.serverState;
          yield* handler.serverStateStream;
        }),
        lyricRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await handler.disposeHandler();
    });
    final listener = container.listen(lyricViewModelProvider, (_, _) {});
    addTearDown(listener.close);
    await pumpEventQueue();
    expect(repository.requests, [uiTrack.id]);
    const next = HMusicTrack(
      id: 'test:next',
      source: 'test',
      sourceTrackId: 'next',
      title: '下一首',
      artist: '测试歌手',
    );
    handler.emit(uiPlayback().update(track: next));
    await pumpEventQueue();
    repository.pending[next.id]!.complete(const HMusicLyric(lrc: '新歌词'));
    repository.pending[uiTrack.id]!.complete(const HMusicLyric(lrc: '旧歌词'));
    await pumpEventQueue();
    expect(container.read(lyricViewModelProvider).lyric?.lrc, '新歌词');
    handler.emit(uiPlayback().update(track: next, positionMs: 48000));
    await pumpEventQueue();
    expect(repository.requests, [uiTrack.id, next.id]);
  });
}
