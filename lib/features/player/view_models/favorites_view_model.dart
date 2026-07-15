import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/hmusic_track.dart';
import '../../../core/network/api_failure.dart';
import '../../playlists/data/api_playlists_repository.dart';
import '../../playlists/data/playlists_repository.dart';
import '../../playlists/models/playlist.dart';
import '../models/favorites_state.dart';

// 「我喜欢的音乐」= 同名普通歌单，首次收藏时自动创建（对齐 web player.js）。
const String kFavoritesPlaylistName = '我喜欢的音乐';

final NotifierProvider<FavoritesViewModel, FavoritesState>
favoritesViewModelProvider =
    NotifierProvider<FavoritesViewModel, FavoritesState>(
      FavoritesViewModel.new,
    );

class FavoritesViewModel extends Notifier<FavoritesState> {
  @override
  FavoritesState build() => const FavoritesState();

  // 曲目判重键：与 web 一致用 source:sourceTrackId（id 可能因解析批次不同）。
  static String _keyOf(HMusicTrack track) =>
      '${track.source}:${track.sourceTrackId}';

  PlaylistItem? itemFor(HMusicTrack? track) {
    final items = state.playlist?.items;
    if (track == null || items == null) return null;
    final key = _keyOf(track);
    for (final item in items) {
      if (_keyOf(item.track) == key) return item;
    }
    return null;
  }

  // 拉收藏歌单快照。尽力而为（web 同款）：失败静默，心形保持空心可重试。
  Future<void> load() async {
    try {
      final playlists = await _repository.getPlaylists();
      PlaylistSummary? summary;
      for (final p in playlists) {
        if (p.name == kFavoritesPlaylistName) {
          summary = p;
          break;
        }
      }
      if (summary == null) return;
      state = state.copyWith(
        playlist: await _repository.getPlaylist(summary.id),
      );
    } on ApiFailure {
      // 收藏状态不打扰播放；下次进播放页或点按钮时再取。
    }
  }

  // 收藏/取消收藏当前曲目；ApiFailure 冒泡给按钮弹提示。
  Future<void> toggle(HMusicTrack track) async {
    if (state.busy) return;
    state = state.copyWith(busy: true);
    try {
      final existing = itemFor(track);
      if (existing != null) {
        state = state.copyWith(
          playlist: await _repository.removeItem(
            state.playlist!.id,
            existing.id,
          ),
        );
      } else {
        final playlist =
            state.playlist ??
            await _repository.createPlaylist(kFavoritesPlaylistName);
        state = state.copyWith(
          playlist: await _repository.addTrack(playlist.id, track),
        );
      }
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  PlaylistsRepository get _repository => ref.read(playlistsRepositoryProvider);
}
