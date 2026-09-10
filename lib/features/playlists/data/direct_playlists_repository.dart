import 'dart:math';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/direct/music/direct_playlist_importer.dart';
import '../../../core/direct/music/platform_track_mapper.dart';
import '../../../core/direct/playback/direct_playback_repository.dart';
import '../../../core/direct/storage/direct_local_store.dart';
import '../../../core/models/hmusic_track.dart';
import '../../../core/network/api_failure.dart';
import '../models/playlist.dart';
import 'playlists_repository.dart';

class DirectPlaylistsRepository implements PlaylistsRepository {
  const DirectPlaylistsRepository(this._store, this._importer, this._playback);
  final DirectLocalStore _store;
  final DirectPlaylistImporter _importer;
  final DirectPlaybackRepository _playback;

  @override
  Future<List<PlaylistSummary>> getPlaylists() async =>
      _lists(await _store.read('playlists'))
          .map(
            (list) => PlaylistSummary(
              id: list.id,
              name: list.name,
              trackCount: list.items.length,
              description: list.description,
            ),
          )
          .toList();

  @override
  Future<PlaylistDetail> getPlaylist(String id) async =>
      _find(_lists(await _store.read('playlists')), id);

  @override
  Future<PlaylistDetail> createPlaylist(String name) => _create(name, []);

  Future<PlaylistDetail> _create(String name, List<HMusicTrack> tracks) =>
      _store.update('playlists', (data) {
        if (name.trim().isEmpty || name.trim().length > 80) {
          throw const ApiFailure(
            kind: ApiFailureKind.invalidConfiguration,
            message: '歌单名称需为 1–80 个字符',
          );
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        final playlist = PlaylistDetail(
          id: _id(),
          name: name.trim(),
          trackCount: tracks.length,
          createdAt: now,
          updatedAt: now,
          items: [
            for (var i = 0; i < tracks.length; i++)
              PlaylistItem(
                id: _id(),
                track: tracks[i],
                position: i,
                addedAt: now,
              ),
          ],
        );
        data['items'] = [
          ..._lists(data).map((list) => list.toJson()),
          playlist.toJson(),
        ];
        return playlist;
      });

  @override
  Future<PlaylistDetail> addTrack(String playlistId, HMusicTrack track) =>
      _edit(playlistId, (list) {
        if (list.items.any((item) => item.track.id == track.id)) {
          return list.items;
        }
        return [
          ...list.items,
          PlaylistItem(
            id: _id(),
            track: track,
            position: list.items.length,
            addedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        ];
      });

  @override
  Future<PlaylistDetail> removeItem(String playlistId, String itemId) => _edit(
    playlistId,
    (list) => list.items.where((item) => item.id != itemId).toList(),
  );

  Future<PlaylistDetail> _edit(
    String id,
    List<PlaylistItem> Function(PlaylistDetail) edit,
  ) => _store.update('playlists', (data) {
    final lists = _lists(data), original = _find(_lists(data), id);
    final items = edit(original);
    final result = PlaylistDetail(
      id: original.id,
      name: original.name,
      description: original.description,
      createdAt: original.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      trackCount: items.length,
      items: [
        for (var i = 0; i < items.length; i++)
          PlaylistItem(
            id: items[i].id,
            track: items[i].track,
            position: i,
            addedAt: items[i].addedAt,
          ),
      ],
    );
    data['items'] = [
      for (final list in lists) (list.id == id ? result : list).toJson(),
    ];
    return result;
  });

  @override
  Future<void> deletePlaylist(String id) async {
    await _store.update('playlists', (data) {
      data['items'] = _lists(
        data,
      ).where((list) => list.id != id).map((list) => list.toJson()).toList();
    });
  }

  @override
  Future<PlaylistImportResult> importPlaylist(String url) async {
    final imported = await _importer.import(url);
    final seen = <String>{}, tracks = <HMusicTrack>[];
    var duplicate = 0,
        empty = 0,
        truncated = max(0, imported.total - imported.tracks.length);
    for (final track in imported.tracks) {
      if (track.title.isEmpty || track.sourceTrackId.isEmpty) {
        empty++;
      } else if (!seen.add(track.id)) {
        duplicate++;
      } else if (tracks.length >= 500) {
        truncated++;
      } else {
        tracks.add(track);
      }
    }
    final name = imported.name.trim().isEmpty ? '导入的歌单' : imported.name.trim();
    final playlist = await _create(
      name.length > 80 ? name.substring(0, 80) : name,
      tracks,
    );
    return PlaylistImportResult(
      name: playlist.name,
      imported: tracks.length,
      skipDuplicate: duplicate,
      skipEmptyTitle: empty,
      skipTruncated: truncated,
    );
  }

  @override
  Future<HMusicPlaybackState> playAll(String id, {int startIndex = 0}) async =>
      _playback.playQueue(
        (await getPlaylist(id)).items.map((item) => item.track).toList(),
        startIndex: startIndex,
      );

  List<PlaylistDetail> _lists(Map<String, Object?> data) =>
      musicRows(data['items']).map(PlaylistDetail.fromJson).toList();
  PlaylistDetail _find(List<PlaylistDetail> lists, String id) =>
      lists.where((list) => list.id == id).firstOrNull ??
      (throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '歌单已不存在，请刷新列表',
      ));
  String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
}
