import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart'
    show PlayMode;
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/core/network/api_client.dart';
import 'package:hmusic/core/queue/api_queue_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

HMusicTrack _track(String id) => HMusicTrack(
  id: id,
  source: 'tx',
  sourceTrackId: id,
  title: 'Song $id',
  artist: 'Artist',
);

Map<String, Object?> _queueJson(int currentIndex) => <String, Object?>{
  'sessionId': 'default',
  'items': <Object?>[],
  'currentIndex': currentIndex,
  'playMode': 'list_loop',
  'updatedAt': 0,
};

void main() {
  late _MockApiClient apiClient;
  late ApiQueueRepository repository;

  setUpAll(() => registerFallbackValue(<String, Object?>{}));

  setUp(() {
    apiClient = _MockApiClient();
    repository = ApiQueueRepository(apiClient: apiClient);
  });

  test('setPlayMode sends the wire enum name', () async {
    when(
      () => apiClient.postMap('/queue/mode', body: any(named: 'body')),
    ).thenAnswer((_) async => _queueJson(0));

    await repository.setPlayMode(PlayMode.singleLoop);

    final captured =
        verify(
              () => apiClient.postMap(
                '/queue/mode',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, Object?>;
    expect(captured['playMode'], 'single_loop');
  });

  test('replaceQueue serializes tracks and omits unknown play mode', () async {
    when(
      () => apiClient.putMap('/queue', body: any(named: 'body')),
    ).thenAnswer((_) async => _queueJson(1));

    await repository.replaceQueue(
      tracks: <HMusicTrack>[_track('a'), _track('b')],
      currentIndex: 1,
      playMode: PlayMode.unknown,
    );

    final body =
        verify(
              () => apiClient.putMap('/queue', body: captureAny(named: 'body')),
            ).captured.single
            as Map<String, Object?>;
    expect((body['tracks']! as List<Object?>).length, 2);
    expect(body['currentIndex'], 1);
    expect(body.containsKey('playMode'), isFalse);
  });

  test('setCurrentIndex posts the index', () async {
    when(
      () => apiClient.postMap('/queue/current', body: any(named: 'body')),
    ).thenAnswer((_) async => _queueJson(2));

    final queue = await repository.setCurrentIndex(2);

    expect(queue.currentIndex, 2);
    final body =
        verify(
              () => apiClient.postMap(
                '/queue/current',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, Object?>;
    expect(body['index'], 2);
  });
}
