import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../../../core/security/token_store.dart';
import '../models/config_options.dart';
import '../models/server_config.dart';
import '../models/settings_summary.dart';
import 'settings_repository.dart';

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) {
      return ApiSettingsRepository(
        apiClient: ref.watch(apiClientProvider),
        tokenStore: ref.watch(tokenStoreProvider),
      );
    });

class ApiSettingsRepository implements SettingsRepository {
  const ApiSettingsRepository({
    required ApiClient apiClient,
    required TokenStore tokenStore,
  }) : _apiClient = apiClient,
       _tokenStore = tokenStore;

  final ApiClient _apiClient;
  final TokenStore _tokenStore;

  @override
  Future<SettingsSummary> loadSummary() async {
    // 五路并发、各自容错：任何一路失败只让对应摘要留空，不拖垮整页。
    final results = await Future.wait(<Future<Map<String, Object?>?>>[
      _tryGet('/mi/status'),
      _tryGet('/devices'),
      _tryGet('/sources/lx-plugins'),
      _tryGet('/config'),
      _tryGet('/downloads'),
    ]);
    final mi = results[0];
    final devices = _asList(results[1]?['devices']);
    final plugins = _asList(results[2]?['plugins']);
    final config = results[3];
    final downloads = _asList(results[4]?['downloads']);

    final defaultDevice = devices
        .whereType<Map<String, Object?>>()
        .where((d) => d['isDefault'] == true)
        .firstOrNull;
    final doneCount = downloads
        .whereType<Map<String, Object?>>()
        .where((d) => d['status'] == 'done')
        .length;

    return SettingsSummary(
      mi: mi == null
          ? ''
          : mi['loggedIn'] == true
          ? '已登录 ${mi['accountMasked'] ?? ''}'.trim()
          : '未登录',
      devices: defaultDevice != null
          ? '${defaultDevice['name']}'
          : '${devices.length} 台',
      sources: '${plugins.length} 个',
      downloads: '$doneCount 首',
      tracks: '${_asList(config?['manualTracks']).length} 首',
      config: config == null
          ? ''
          : '${config['defaultQuality']} · '
                '${configOptionLabel(kSearchStrategyOptions, '${config['searchStrategy']}')}',
    );
  }

  @override
  Future<ServerConfig> getConfig() async {
    return ServerConfig.fromJson(await _apiClient.getMap('/config'));
  }

  @override
  Future<ServerConfig> patchConfig({
    String? serverName,
    String? defaultQuality,
    String? searchStrategy,
    String? resolveStrategy,
    List<String>? extraPlayMusicModels,
    List<ManualTrack>? manualTracks,
    bool? announceTracks,
  }) async {
    final payload = await _apiClient.patchMap(
      '/config',
      body: <String, Object?>{
        if (serverName != null) 'serverName': serverName,
        if (defaultQuality != null) 'defaultQuality': defaultQuality,
        if (searchStrategy != null) 'searchStrategy': searchStrategy,
        if (resolveStrategy != null) 'resolveStrategy': resolveStrategy,
        if (extraPlayMusicModels != null)
          'extraPlayMusicModels': extraPlayMusicModels,
        if (manualTracks != null)
          'manualTracks': manualTracks.map((t) => t.toJson()).toList(),
        if (announceTracks != null) 'announceTracks': announceTracks,
      },
    );
    return ServerConfig.fromJson(payload);
  }

  @override
  Future<HMusicPlaybackState> getPlaybackState() async {
    return HMusicPlaybackState.fromJson(
      await _apiClient.getMap('/playback/state'),
    );
  }

  @override
  Future<void> playTestTone() async {
    await _apiClient.postMap('/playback/test-tone');
  }

  @override
  Future<void> speak(String text) async {
    await _apiClient.postMap(
      '/playback/speak',
      body: <String, Object?>{'text': text},
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final payload = await _apiClient.postMap(
      '/auth/password',
      body: <String, Object?>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    // 服务端换发新 token，立即落盘避免旧 token 失效后被踢回登录页。
    final token = payload['accessToken'];
    if (token is String && token.isNotEmpty) {
      await _tokenStore.write(token);
    }
  }

  Future<Map<String, Object?>?> _tryGet(String path) async {
    try {
      return await _apiClient.getMap(path);
    } catch (_) {
      return null;
    }
  }

  List<Object?> _asList(Object? value) {
    return value is List<Object?> ? value : const <Object?>[];
  }
}
