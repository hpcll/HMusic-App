import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/hmusic_track.dart';
import '../../../core/network/api_failure.dart';
import '../data/api_lyric_repository.dart';
import '../models/hmusic_lyric.dart';

// 歌词缓存状态（对齐 web lyric-state.js）：播放页染色条与沉浸歌词页共享，
// 同一首歌（source:sourceTrackId）只拉一次 /tracks/lyrics。
class LyricState {
  const LyricState({this.lyric, this.loading = false});

  final HMusicLyric? lyric;
  final bool loading;

  List<LyricLine> get lines => lyric?.lines ?? const <LyricLine>[];

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

  @override
  LyricState build() => const LyricState();

  // track 变化时调用；null（无播放）清空缓存。同曲直接返回。
  Future<void> ensureLyric(HMusicTrack? track) async {
    if (track == null) {
      _loadedKey = '';
      state = const LyricState();
      return;
    }
    final key = '${track.source}:${track.sourceTrackId}';
    if (key == _loadedKey) return;
    _loadedKey = key;
    state = state.copyWith(clearLyric: true, loading: true);
    try {
      final lyric = await ref.read(lyricRepositoryProvider).fetchLyric(track);
      // 异步返回时曲目已切换则丢弃（防竞态）。
      if (key != _loadedKey) return;
      state = LyricState(lyric: lyric, loading: false);
    } on ApiFailure {
      // 无歌词不算错误（纯音乐/音源未提供），静默降级为空。
      if (key != _loadedKey) return;
      state = const LyricState(loading: false);
    }
  }

  // 给定播放位置，返回当前行索引（最后一个 timeMs<=pos 的行），无则 -1。
  int activeLineFor(int positionMs) {
    final lines = state.lines;
    var active = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].timeMs <= positionMs) {
        active = i;
      } else {
        break;
      }
    }
    return active;
  }
}
