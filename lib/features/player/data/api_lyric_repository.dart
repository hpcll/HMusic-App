import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/direct/direct_providers.dart';
import '../../../core/models/hmusic_track.dart';
import '../../../core/network/api_client.dart';
import '../../../core/playback/playback_mode.dart';
import '../../../core/playback/playback_mode_controller.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../models/hmusic_lyric.dart';
import 'direct_lyric_repository.dart';
import 'lyric_repository.dart';

final Provider<LyricRepository> lyricRepositoryProvider =
    Provider<LyricRepository>((ref) {
      if (ref.watch(playbackModeProvider) == PlaybackMode.direct) {
        return DirectLyricRepository(
          ref.watch(directMusicHttpProvider),
          ref.watch(directLxSourcesProvider),
        );
      }
      return ApiLyricRepository(apiClient: ref.watch(apiClientProvider));
    });

class ApiLyricRepository implements LyricRepository {
  const ApiLyricRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<HMusicLyric> fetchLyric(HMusicTrack track) async {
    final payload = await _apiClient.postMap(
      '/tracks/lyrics',
      body: <String, Object?>{'track': track.toJson()},
    );
    return HMusicLyric.fromJson(payload);
  }
}
