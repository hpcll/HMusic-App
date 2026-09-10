import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/config/build_edition.dart';
import '../../../core/direct/direct_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/playback/playback_mode.dart';
import '../../../core/playback/playback_mode_controller.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../../search/data/api_search_repository.dart';
import '../models/chart.dart';
import 'charts_repository.dart';
import 'direct_chart_playback.dart';
import 'direct_chart_source.dart';
import 'direct_charts_repository.dart';

final Provider<ChartsRepository> chartsRepositoryProvider =
    Provider<ChartsRepository>((ref) {
      if (ref.watch(playbackModeProvider) == PlaybackMode.direct) {
        final repository = DirectChartsRepository(
          source: DirectChartSource(
            ref.watch(directMusicHttpProvider),
            ref.watch(directPlaylistImporterProvider),
          ),
          playback: DirectChartPlayback(
            ref.watch(directPlaybackRepositoryProvider),
            ref.watch(directQueueRepositoryProvider),
            ref.watch(searchRepositoryProvider),
          ),
          store: ref.watch(directLocalStoreProvider),
        );
        ref.onDispose(repository.dispose);
        return repository;
      }
      return ApiChartsRepository(apiClient: ref.watch(apiClientProvider));
    });

class ApiChartsRepository implements ChartsRepository {
  const ApiChartsRepository({
    required ApiClient apiClient,
    bool includeSpotify = !BuildEdition.isStore,
  }) : _apiClient = apiClient,
       _includeSpotify = includeSpotify;

  final ApiClient _apiClient;
  final bool _includeSpotify;

  @override
  Future<List<Chart>> getCharts() async {
    final payload = await _apiClient.getMap(
      '/charts',
      query: _includeSpotify
          ? null
          : const <String, Object?>{'includeSpotify': false},
    );
    final list = payload['charts'];
    if (list is! List) return const <Chart>[];
    return list
        .whereType<Map<String, Object?>>()
        .map(Chart.fromJson)
        .where((chart) => _includeSpotify || !chart.kind.startsWith('spotify'))
        .toList(growable: false);
  }

  @override
  Future<ChartDetail> getChart(String id) async {
    _checkAllowed(id);
    return ChartDetail.fromJson(
      await _apiClient.getMap('/charts/${Uri.encodeComponent(id)}'),
    );
  }

  @override
  Future<HMusicPlaybackState> playAll(String id, {int? startIndex}) async {
    _checkAllowed(id);
    // 同歌单整单播放：不带 deviceId，服务端 resolve 用户选定的默认设备，
    // 权威 playback 带回给调用方注入 AudioHandler。
    final payload = await _apiClient.postMap(
      '/charts/${Uri.encodeComponent(id)}/play',
      body: <String, Object?>{if (startIndex != null) 'startIndex': startIndex},
    );
    final playback = payload['playback'];
    return HMusicPlaybackState.fromJson(
      playback is Map<String, Object?> ? playback : payload,
    );
  }

  void _checkAllowed(String id) {
    if (!_includeSpotify && id.startsWith('spotify-')) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '当前版本不提供 Spotify 个人通道',
      );
    }
  }
}
