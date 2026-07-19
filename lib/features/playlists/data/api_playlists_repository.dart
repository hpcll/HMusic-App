import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/models/hmusic_track.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../models/playlist.dart';
import 'playlists_repository.dart';

final Provider<PlaylistsRepository> playlistsRepositoryProvider =
    Provider<PlaylistsRepository>((ref) {
      return ApiPlaylistsRepository(apiClient: ref.watch(apiClientProvider));
    });

class ApiPlaylistsRepository implements PlaylistsRepository {
  const ApiPlaylistsRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<PlaylistSummary>> getPlaylists() async {
    final payload = await _apiClient.getMap('/playlists');
    final list = payload['playlists'];
    if (list is! List) return const <PlaylistSummary>[];
    return list
        .whereType<Map<String, Object?>>()
        .map(PlaylistSummary.fromJson)
        .toList(growable: false);
  }

  // 单歌单接口返回都包在 { playlist } 里。
  @override
  Future<PlaylistDetail> getPlaylist(String id) async {
    return _unwrap(await _apiClient.getMap('/playlists/$id'));
  }

  @override
  Future<PlaylistDetail> createPlaylist(String name) async {
    return _unwrap(
      await _apiClient.postMap(
        '/playlists',
        body: <String, Object?>{'name': name},
      ),
    );
  }

  @override
  Future<PlaylistDetail> addTrack(String playlistId, HMusicTrack track) async {
    return _unwrap(
      await _apiClient.postMap(
        '/playlists/$playlistId/tracks',
        body: <String, Object?>{'track': track.toJson()},
      ),
    );
  }

  @override
  Future<PlaylistImportResult> importPlaylist(String url) async {
    final payload = await _apiClient.postMap(
      '/playlists/import',
      body: <String, Object?>{'url': url},
    );
    return PlaylistImportResult.fromJson(payload);
  }

  @override
  Future<void> deletePlaylist(String id) async {
    await _apiClient.deleteMap('/playlists/$id');
  }

  @override
  Future<PlaylistDetail> removeItem(String playlistId, String itemId) async {
    return _unwrap(
      await _apiClient.deleteMap('/playlists/$playlistId/tracks/$itemId'),
    );
  }

  @override
  Future<HMusicPlaybackState> playAll(String id, {int startIndex = 0}) async {
    // 不带 deviceId：服务端 resolve 用户选定的默认设备（音箱选中时整单播到
    // 音箱，遥控语义）。权威 playback 带回给调用方注入 AudioHandler，目标为
    // 本机时由它装载出声，为远端时停本机。
    final payload = await _apiClient.postMap(
      '/playlists/$id/play',
      body: <String, Object?>{'startIndex': startIndex},
    );
    final playback = payload['playback'];
    return HMusicPlaybackState.fromJson(
      playback is Map<String, Object?> ? playback : payload,
    );
  }

  PlaylistDetail _unwrap(Map<String, Object?> payload) {
    final playlist = payload['playlist'];
    if (playlist is Map<String, Object?>) {
      return PlaylistDetail.fromJson(playlist);
    }
    // 兼容未包裹的返回。
    return PlaylistDetail.fromJson(payload);
  }
}
