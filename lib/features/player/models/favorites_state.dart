import '../../playlists/models/playlist.dart';

// 收藏（「我喜欢的音乐」歌单）状态：detail 缓存 + 防重入。
// playlist == null 表示未加载成功或服务端尚无该歌单（首次收藏时自动创建）。
class FavoritesState {
  const FavoritesState({this.playlist, this.busy = false});

  final PlaylistDetail? playlist;
  final bool busy;

  FavoritesState copyWith({PlaylistDetail? playlist, bool? busy}) {
    return FavoritesState(
      playlist: playlist ?? this.playlist,
      busy: busy ?? this.busy,
    );
  }
}
