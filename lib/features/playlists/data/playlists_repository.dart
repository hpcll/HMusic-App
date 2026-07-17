import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/models/hmusic_track.dart';
import '../models/playlist.dart';

// 歌单数据契约：列表、详情、创建、导入、删除、加/移除曲目、整单播放。
abstract interface class PlaylistsRepository {
  Future<List<PlaylistSummary>> getPlaylists();

  Future<PlaylistDetail> getPlaylist(String id);

  // 返回创建结果：收藏首建「我喜欢的音乐」后要立刻拿 id 加歌。
  Future<PlaylistDetail> createPlaylist(String name);

  Future<PlaylistDetail> addTrack(String playlistId, HMusicTrack track);

  Future<PlaylistImportResult> importPlaylist(String url);

  Future<void> deletePlaylist(String id);

  Future<PlaylistDetail> removeItem(String playlistId, String itemId);

  // 返回服务端开播后的权威播放状态，调用方喂给 AudioHandler 本机出声。
  Future<HMusicPlaybackState> playAll(String id, {int startIndex = 0});
}
