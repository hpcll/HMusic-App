import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/hmusic_track.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/playback/backend_request.dart';
import '../data/api_lyric_repository.dart';
import '../models/hmusic_lyric.dart';
import 'player_view_model.dart';

// 歌词缓存状态（对齐 web lyric-state.js）：播放页染色条与沉浸歌词页共享，
// 同一首歌（source:sourceTrackId）只拉一次 /tracks/lyrics。
class LyricState {
  const LyricState({this.lyric, this.loading = false});

  final HMusicLyric? lyric;
  final bool loading;

  List<LyricLine> get lines => lyric?.lines ?? const <LyricLine>[];

  int activeLineFor(int positionMs) {
    var active = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].timeMs > positionMs) break;
      active = i;
    }
    return active;
  }

  LyricState copyWith({
    HMusicLyric? lyric,
    bool? loading,
    bool clearLyric = false,
  }) {
    return LyricState(
      lyric: clearLyric ? null : (lyric ?? this.lyric),
      loading: loading ?? this.loading,
    );
  }
}

final NotifierProvider<LyricViewModel, LyricState> lyricViewModelProvider =
    NotifierProvider<LyricViewModel, LyricState>(LyricViewModel.new);

class LyricViewModel extends Notifier<LyricState> {
  // 当前已缓存歌词对应的曲目 key，同 key 不重复请求。
  String _loadedKey = '';
  int _requestId = 0;

  @override
  LyricState build() {
    ref.watch(lyricRepositoryProvider);
    _loadedKey = '';
    _requestId++;
    ref.listen(serverPlaybackStateProvider, (_, next) {
      if (next.isLoading || !next.hasValue) return;
      final request = BackendRequest(ref);
      unawaited(
        Future<void>.microtask(() async {
          if (request.current) await ensureLyric(next.value?.track);
        }),
      );
    }, fireImmediately: true);
    return const LyricState();
  }

  // track 变化时调用；null（无播放）清空缓存。同曲直接返回。
  Future<void> ensureLyric(HMusicTrack? track) async {
    final request = BackendRequest(ref);
    if (track == null) {
      _requestId++;
      _loadedKey = '';
      state = const LyricState();
      return;
    }
    final key = '${track.source}:${track.sourceTrackId}';
    if (key == _loadedKey) return;
    final requestId = ++_requestId;
    _loadedKey = key;
    state = state.copyWith(clearLyric: true, loading: true);
    try {
      final lyric = await ref.read(lyricRepositoryProvider).fetchLyric(track);
      // 异步返回时曲目已切换则丢弃（防竞态）。
      if (!request.current || requestId != _requestId || key != _loadedKey) {
        return;
      }
      state = LyricState(lyric: lyric, loading: false);
    } on ApiFailure {
      // 无歌词不算错误（纯音乐/音源未提供），静默降级为空。
      if (!request.current || requestId != _requestId || key != _loadedKey) {
        return;
      }
      state = const LyricState(loading: false);
    }
  }
}
