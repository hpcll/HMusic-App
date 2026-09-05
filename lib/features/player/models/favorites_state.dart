import '../../playlists/models/playlist.dart';

// 收藏（「我喜欢的音乐」歌单）状态：detail 缓存 + 防重入 + 最近一次失败。
// playlist == null 表示未加载成功或服务端尚无该歌单（首次收藏时自动创建）。
// error 由播放页就地内联渲染（心形不变 = 失败，文字说明原因），新动作即清除。
class FavoritesState {
  const FavoritesState({this.playlist, this.busy = false, this.error});

  final PlaylistDetail? playlist;
  final bool busy;
  final String? error;

  FavoritesState copyWith({
    PlaylistDetail? playlist,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return FavoritesState(
      playlist: playlist ?? this.playlist,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
