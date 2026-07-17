import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/core/network/api_client.dart';
import 'package:hmusic/features/playlists/data/api_playlists_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

const HMusicTrack _track = HMusicTrack(
  id: 'tx:1',
  source: 'tx',
  sourceTrackId: '1',
  title: '晴天',
  artist: '周杰伦',
  album: '叶惠美',
);

Map<String, Object?> _playlistJson() => <String, Object?>{
  'playlist': <String, Object?>{
    'id': 'fav',
    'name': '我喜欢的音乐',
    'items': <Object?>[
      <String, Object?>{'id': 'item-1', 'track': _track.toJson()},
    ],
  },
};

void main() {
  late _MockApiClient apiClient;
  late ApiPlaylistsRepository repository;

  setUpAll(() => registerFallbackValue(<String, Object?>{}));

  setUp(() {
    apiClient = _MockApiClient();
    repository = ApiPlaylistsRepository(apiClient: apiClient);
  });

  test('addTrack posts wrapped track json and unwraps {playlist}', () async {
    when(
      () =>
          apiClient.postMap('/playlists/fav/tracks', body: any(named: 'body')),
    ).thenAnswer((_) async => _playlistJson());

    final detail = await repository.addTrack('fav', _track);

    final body =
        verify(
              () => apiClient.postMap(
                '/playlists/fav/tracks',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, Object?>;
    // 线格式对齐 web player.js：{track: <HMusicTrack json>}。
    final track = body['track']! as Map<String, Object?>;
    expect(track['source'], 'tx');
    expect(track['sourceTrackId'], '1');
    expect(track['title'], '晴天');

    expect(detail.id, 'fav');
    expect(detail.items.single.id, 'item-1');
    expect(detail.items.single.track.title, '晴天');
  });

  test(
    'createPlaylist returns created detail (favorites first-save)',
    () async {
      when(
        () => apiClient.postMap('/playlists', body: any(named: 'body')),
      ).thenAnswer(
        (_) async => <String, Object?>{
          'playlist': <String, Object?>{'id': 'fav', 'name': '我喜欢的音乐'},
        },
      );

      final detail = await repository.createPlaylist('我喜欢的音乐');

      final body =
          verify(
                () => apiClient.postMap(
                  '/playlists',
                  body: captureAny(named: 'body'),
                ),
              ).captured.single
              as Map<String, Object?>;
      expect(body, <String, Object?>{'name': '我喜欢的音乐'});
      // 返回的 id 是首次收藏后续 addTrack 的目标。
      expect(detail.id, 'fav');
      expect(detail.items, isEmpty);
    },
  );

  test('removeItem deletes by itemId and unwraps {playlist}', () async {
    when(() => apiClient.deleteMap('/playlists/fav/tracks/item-1')).thenAnswer(
      (_) async => <String, Object?>{
        'playlist': <String, Object?>{
          'id': 'fav',
          'name': '我喜欢的音乐',
          'items': <Object?>[],
        },
      },
    );

    final detail = await repository.removeItem('fav', 'item-1');

    verify(() => apiClient.deleteMap('/playlists/fav/tracks/item-1')).called(1);
    expect(detail.items, isEmpty);
  });

  test('playAll 指定本机设备并返回权威 playback', () async {
    when(
      () => apiClient.postMap('/playlists/fav/play', body: any(named: 'body')),
    ).thenAnswer(
      (_) async => <String, Object?>{
        'queue': <String, Object?>{},
        'playback': <String, Object?>{
          'sessionId': 's1',
          'deviceId': 'local-browser',
          'state': 'playing',
          'track': _track.toJson(),
          'positionMs': 0,
          'durationMs': 254000,
          'volume': 1,
          'playMode': 'list_loop',
          'queueIndex': 2,
          'queueLength': 12,
          'seekEnabled': true,
          'streamUrl': 'http://origin.example/stream/1.mp3',
          'updatedAt': 1700000000000,
        },
      },
    );

    final playback = await repository.playAll('fav', startIndex: 2);

    final body =
        verify(
              () => apiClient.postMap(
                '/playlists/fav/play',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, Object?>;
    // 不带 deviceId 时服务端会播到默认设备，本机静音——契约必须锁死。
    expect(body, <String, Object?>{
      'startIndex': 2,
      'deviceId': 'local-browser',
    });
    expect(playback.deviceId, 'local-browser');
    expect(playback.state, PlaybackStatus.playing);
    expect(playback.track?.title, '晴天');
  });
}
