import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/features/playlists/data/playlists_repository.dart';
import 'package:hmusic/features/playlists/models/playlist.dart';

// 内存版歌单仓库（收藏链路测试共用）：只实现收藏用到的五个方法，
// 其余按未实现抛错；calls 记录调用序列供断言。
class FakePlaylistsRepository implements PlaylistsRepository {
  FakePlaylistsRepository({this.favorites});

  PlaylistDetail? favorites;
  final List<String> calls = <String>[];

  @override
  Future<List<PlaylistSummary>> getPlaylists() async {
    calls.add('list');
    final detail = favorites;
    if (detail == null) return const <PlaylistSummary>[];
    return <PlaylistSummary>[
      PlaylistSummary(
        id: detail.id,
        name: detail.name,
        trackCount: detail.items.length,
      ),
    ];
  }

  @override
  Future<PlaylistDetail> getPlaylist(String id) async {
    calls.add('get:$id');
    return favorites!;
  }

  @override
  Future<PlaylistDetail> createPlaylist(String name) async {
    calls.add('create:$name');
    favorites = PlaylistDetail(id: 'fav', name: name);
    return favorites!;
  }

  @override
  Future<PlaylistDetail> addTrack(String playlistId, HMusicTrack track) async {
    calls.add('add:$playlistId:${track.sourceTrackId}');
    final detail = favorites!;
    favorites = PlaylistDetail(
      id: detail.id,
      name: detail.name,
      items: <PlaylistItem>[
        ...detail.items,
        PlaylistItem(id: 'item-${track.sourceTrackId}', track: track),
      ],
    );
    return favorites!;
  }

  @override
  Future<PlaylistDetail> removeItem(String playlistId, String itemId) async {
    calls.add('remove:$playlistId:$itemId');
    final detail = favorites!;
    favorites = PlaylistDetail(
      id: detail.id,
      name: detail.name,
      items: detail.items
          .where((item) => item.id != itemId)
          .toList(growable: false),
    );
    return favorites!;
  }

  @override
  Future<PlaylistImportResult> importPlaylist(String url) =>
      throw UnimplementedError();

  @override
  Future<void> deletePlaylist(String id) => throw UnimplementedError();

  @override
  Future<void> playAll(String id, {int startIndex = 0}) =>
      throw UnimplementedError();
}
