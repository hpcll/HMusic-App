import '../models/playlist.dart';

// 歌单数据契约：列表、详情、创建、导入、删除、移除曲目、整单播放。
abstract interface class PlaylistsRepository {
  Future<List<PlaylistSummary>> getPlaylists();

  Future<PlaylistDetail> getPlaylist(String id);

  Future<void> createPlaylist(String name);

  Future<PlaylistImportResult> importPlaylist(String url);

  Future<void> deletePlaylist(String id);

  Future<PlaylistDetail> removeItem(String playlistId, String itemId);

  Future<void> playAll(String id, {int startIndex = 0});
}
