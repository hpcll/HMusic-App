import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../models/lx_plugin.dart';
import 'sources_repository.dart';

final Provider<SourcesRepository> sourcesRepositoryProvider =
    Provider<SourcesRepository>((ref) {
      return ApiSourcesRepository(apiClient: ref.watch(apiClientProvider));
    });

class ApiSourcesRepository implements SourcesRepository {
  const ApiSourcesRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<LxPlugin>> listPlugins() async {
    final payload = await _apiClient.getMap('/sources/lx-plugins');
    final items = payload['plugins'];
    if (items is! List<Object?>) return const <LxPlugin>[];
    return items
        .whereType<Map<String, Object?>>()
        .map(LxPlugin.fromJson)
        .toList();
  }

  @override
  Future<Map<String, SourceHealth>> loadHealth() async {
    final payload = await _apiClient.getMap('/sources');
    final items = payload['sources'];
    if (items is! List<Object?>) return const <String, SourceHealth>{};
    final result = <String, SourceHealth>{};
    for (final source in items.whereType<Map<String, Object?>>()) {
      final id = source['id'];
      if (id is! String) continue;
      final health = source['health'];
      final status = health is Map<String, Object?> ? health['status'] : null;
      result[id] = switch (status) {
        'ok' => SourceHealth.ok,
        'failed' => SourceHealth.failed,
        _ => SourceHealth.unknown,
      };
    }
    return result;
  }

  @override
  Future<String> getCode(String id) async {
    final payload = await _apiClient.getMap('/sources/lx-plugins/${_enc(id)}');
    return '${payload['code'] ?? ''}';
  }

  @override
  Future<LxFetchResult> fetchFromUrl(String url) async {
    final payload = await _apiClient.postMap(
      '/sources/lx-plugins/fetch',
      body: <String, Object?>{'url': url},
    );
    return LxFetchResult.fromJson(payload);
  }

  @override
  Future<void> savePlugin({
    required String id,
    required String name,
    required String code,
    required bool enabled,
    required String defaultQuality,
    String? sourceUrl,
  }) async {
    await _apiClient.postMap(
      '/sources/lx-plugins',
      body: <String, Object?>{
        'id': id,
        'name': name,
        'code': code,
        'enabled': enabled,
        'defaultQuality': defaultQuality,
        if (sourceUrl != null && sourceUrl.isNotEmpty) 'sourceUrl': sourceUrl,
      },
    );
  }

  @override
  Future<void> updatePlugin(String id) async {
    await _apiClient.postMap('/sources/lx-plugins/${_enc(id)}/update');
  }

  @override
  Future<String> testPlugin(String id) async {
    final payload = await _apiClient.postMap('/sources/${_enc(id)}/test');
    return '${payload['message'] ?? '插件加载测试通过'}';
  }

  @override
  Future<void> deletePlugin(String id) async {
    await _apiClient.deleteMap('/sources/lx-plugins/${_enc(id)}');
  }

  // 对齐 web encodeURIComponent：插件 id 可能含保留字符。
  String _enc(String id) => Uri.encodeComponent(id);
}
