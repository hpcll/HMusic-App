import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/models/hmusic_playback_state.dart' show PlayMode, PlayModeWire;
import '../models/hmusic_track.dart';
import '../network/api_client.dart';
import '../providers/infrastructure_providers.dart';
import 'models/hmusic_queue.dart';
import 'queue_repository.dart';

final Provider<QueueRepository> queueRepositoryProvider =
    Provider<QueueRepository>((ref) {
      return ApiQueueRepository(apiClient: ref.watch(apiClientProvider));
    });

class ApiQueueRepository implements QueueRepository {
  const ApiQueueRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<HMusicQueue> getQueue() async {
    return HMusicQueue.fromJson(await _apiClient.getMap('/queue'));
  }

  @override
  Future<HMusicQueue> replaceQueue({
    required List<HMusicTrack> tracks,
    int? currentIndex,
    PlayMode? playMode,
  }) async {
    return HMusicQueue.fromJson(
      await _apiClient.putMap(
        '/queue',
        body: <String, Object?>{
          'tracks': tracks.map((track) => track.toJson()).toList(),
          if (currentIndex != null) 'currentIndex': currentIndex,
          if (playMode?.wireName != null) 'playMode': playMode!.wireName,
        },
      ),
    );
  }

  @override
  Future<HMusicQueue> addTrack(HMusicTrack track) async {
    return HMusicQueue.fromJson(
      await _apiClient.postMap(
        '/queue/items',
        body: <String, Object?>{'track': track.toJson()},
      ),
    );
  }

  @override
  Future<HMusicQueue> setCurrentIndex(int index) async {
    return HMusicQueue.fromJson(
      await _apiClient.postMap(
        '/queue/current',
        body: <String, Object?>{'index': index},
      ),
    );
  }

  @override
  Future<HMusicQueue> setPlayMode(PlayMode playMode) async {
    return HMusicQueue.fromJson(
      await _apiClient.postMap(
        '/queue/mode',
        body: <String, Object?>{'playMode': playMode.wireName},
      ),
    );
  }

  @override
  Future<HMusicQueue> clear() async {
    return HMusicQueue.fromJson(await _apiClient.postMap('/queue/clear'));
  }
}
