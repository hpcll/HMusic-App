import '../../../core/direct/music/direct_lx_sources.dart';
import '../models/lx_plugin.dart';
import 'sources_repository.dart';

class DirectSourcesRepository implements SourcesRepository {
  const DirectSourcesRepository(this._sources);
  final DirectLxSources _sources;
  @override
  Future<List<LxPlugin>> listPlugins() async =>
      (await _sources.list()).map(LxPlugin.fromJson).toList();
  @override
  Future<Map<String, SourceHealth>> loadHealth() async => _sources.health.map(
    (id, status) =>
        MapEntry(id, status == 'ok' ? SourceHealth.ok : SourceHealth.failed),
  );
  @override
  Future<String> getCode(String id) async =>
      '${(await _sources.get(id))['code']}';
  @override
  Future<LxFetchResult> fetchFromUrl(String url) async {
    final code = await _sources.fetch(url);
    String? meta(String name) =>
        RegExp('@$name[ \\t]+([^\\r\\n]+)').firstMatch(code)?.group(1)?.trim();
    return LxFetchResult(
      code: code,
      name: meta('name'),
      version: meta('version'),
    );
  }

  @override
  Future<void> savePlugin({
    required String id,
    required String name,
    required String code,
    required bool enabled,
    required String defaultQuality,
    String? sourceUrl,
  }) => _sources.save({
    'id': id,
    'name': name,
    'code': code,
    'enabled': enabled,
    'defaultQuality': defaultQuality,
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
  });
  @override
  Future<void> updatePlugin(String id) async {
    final plugin = await _sources.get(id);
    final code = await _sources.fetch('${plugin['sourceUrl'] ?? ''}');
    await _sources.save({...plugin, 'code': code});
  }

  @override
  Future<String> testPlugin(String id) => _sources.test(id);
  @override
  Future<void> deletePlugin(String id) => _sources.delete(id);
}
