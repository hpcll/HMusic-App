import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../models/hmusic_device.dart';
import 'devices_repository.dart';

final Provider<DevicesRepository> devicesRepositoryProvider =
    Provider<DevicesRepository>((ref) {
      return ApiDevicesRepository(apiClient: ref.watch(apiClientProvider));
    });

class ApiDevicesRepository implements DevicesRepository {
  const ApiDevicesRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<HMusicDevice>> getDevices() async {
    final payload = await _apiClient.getMap('/devices');
    final items = payload['devices'];
    if (items is! List<Object?>) return const <HMusicDevice>[];
    return items
        .whereType<Map<String, Object?>>()
        .map(HMusicDevice.fromJson)
        .toList();
  }

  @override
  Future<int> refresh() async {
    final payload = await _apiClient.postMap('/devices/refresh');
    return (payload['deviceCount'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<HMusicPlaybackState> select(String deviceId) async {
    final payload = await _apiClient.postMap('/devices/$deviceId/select');
    final playback = payload['playback'];
    if (playback is! Map<String, Object?>) {
      throw Exception('select 响应缺 playback');
    }
    return HMusicPlaybackState.fromJson(playback);
  }

  @override
  Future<void> probe(String deviceId) async {
    await _apiClient.postMap('/devices/$deviceId/probe');
  }
}
