import 'package:flutter_test/flutter_test.dart';
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
}
