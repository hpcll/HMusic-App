import '../../async/serial_executor.dart';
import '../../config/build_edition.dart';
import '../../network/api_failure.dart';
import '../storage/direct_local_store.dart';
import 'direct_music_http.dart';
import 'isolated_lx_runtime.dart';
import 'lx_runtime.dart';
import 'platform_track_mapper.dart';

class DirectLxSources {
  DirectLxSources(
    this._store,
    this._http, {
    LxRuntime Function()? createRuntime,
  }) : _createRuntime = createRuntime ?? IsolatedLxRuntime.new;
  final DirectLocalStore _store;
  final DirectMusicHttp _http;
  final LxRuntime Function() _createRuntime;
  final SerialExecutor _serial = SerialExecutor();
  final Map<String, ({LxRuntime runtime, Map<String, List<String>> sources})>
  _loaded = {};
  final Map<String, String> health = {};
  final Set<LxRuntime> _loading = {};
  int _generation = 0;

  Future<List<Map<String, Object?>>> list() async =>
      musicRows((await _store.read('sources'))['plugins']);

  Future<Map<String, Object?>> get(String id) async {
    final plugin = (await list()).where((p) => p['id'] == id).firstOrNull;
    if (plugin == null) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '音源已不存在，请刷新列表',
      );
    }
    return plugin;
  }

  Future<void> save(Map<String, Object?> plugin) async {
    _requireEdition();
    if ('${plugin['id'] ?? ''}'.isEmpty ||
        '${plugin['code'] ?? ''}'.trim().isEmpty ||
        '${plugin['code']}'.length > 2 * 1024 * 1024) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '音源标识或脚本内容无效（最大 2 MB）',
      );
    }
    await _store.update('sources', (data) {
      data['plugins'] = [
        ...musicRows(data['plugins']).where((p) => p['id'] != plugin['id']),
        plugin,
      ];
    });
    close();
  }

  Future<void> delete(String id) async {
    await _store.update('sources', (data) {
      data['plugins'] = musicRows(
        data['plugins'],
      ).where((p) => p['id'] != id).toList();
    });
    close();
  }

  Future<String> fetch(String url) async {
    _requireEdition();
    final code = await _http.text(url);
    if (code.trim().isEmpty ||
        code.length > 2 * 1024 * 1024 ||
        code.trimLeft().startsWith('<')) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidResponse,
        message: '订阅地址未返回有效的 JavaScript 音源',
      );
    }
    return code;
  }

  Future<String> test(String id) {
    final generation = _generation;
    return _serial.run(() async {
      final plugin = await get(id);
      if (generation != _generation) throw _cancelled;
      final loaded = await _load(plugin);
      return '音源已加载，支持 ${loaded.sources.keys.join(' / ')}';
    });
  }

  Future<Object?> resolve(
    String source,
    String action,
    Map<String, Object?> info, {
    DateTime? deadline,
    Future<void> Function(Object? value)? validate,
  }) {
    final generation = _generation;
    final until = deadline ?? DateTime.now().add(const Duration(seconds: 40));
    return _serial.run(() async {
      _requireEdition();
      if (generation != _generation) throw _cancelled;
      final plugins = (await list())
          .where((p) => p['enabled'] == true)
          .toList();
      if (plugins.isEmpty) {
        throw const ApiFailure(
          kind: ApiFailureKind.invalidConfiguration,
          code: 'DIRECT_SOURCE_MISSING',
          message: '请先在设置的音源页面导入并启用 LX 插件',
        );
      }
      for (final plugin in plugins) {
        if (generation != _generation) throw _cancelled;
        if (!DateTime.now().isBefore(until)) break;
        final id = '${plugin['id']}';
        try {
          final loaded = await _load(plugin, deadline: until);
          final supported = loaded.sources[source];
          if (supported == null) continue;
          final desired =
              '${info['type'] ?? plugin['defaultQuality'] ?? '320k'}';
          final order = ['flac24bit', 'flac', '320k', '128k'];
          final index = order.indexOf(
            desired == 'hires' ? 'flac24bit' : desired,
          );
          final qualities = action == 'musicUrl'
              ? order
                    .skip(index < 0 ? 2 : index)
                    .where(supported.contains)
                    .toList()
              : ['128k'];
          for (final quality in qualities) {
            if (!DateTime.now().isBefore(until)) break;
            try {
              final result = await _bounded(
                loaded.runtime.request(source, action, {
                  ...info,
                  'type': quality,
                }),
                loaded.runtime,
                until,
                const Duration(seconds: 10),
              );
              if (generation != _generation) throw _cancelled;
              if (result == null || result == '') continue;
              await validate?.call(result);
              if (generation != _generation) throw _cancelled;
              health[id] = 'ok';
              return result;
            } on ApiFailure {
              if (generation != _generation) rethrow;
              if (!_loaded.containsKey(id)) break;
            }
          }
        } on ApiFailure {
          if (generation != _generation) rethrow;
        }
        health[id] = 'failed';
      }
      throw const ApiFailure(
        kind: ApiFailureKind.server,
        code: 'DIRECT_RESOLVE_FAILED',
        message: '已启用的音源未能解析此歌曲，请尝试其他歌曲或音源',
      );
    });
  }

  Future<({LxRuntime runtime, Map<String, List<String>> sources})> _load(
    Map<String, Object?> plugin, {
    DateTime? deadline,
  }) async {
    _requireEdition();
    final id = '${plugin['id']}', generation = _generation;
    if (_loaded[id] case final existing?) return existing;
    final runtime = _createRuntime();
    _loading.add(runtime);
    try {
      final sources = await _bounded(
        runtime.start('${plugin['code']}', name: '${plugin['name']}'),
        runtime,
        deadline ?? DateTime.now().add(const Duration(seconds: 15)),
        const Duration(seconds: 15),
      );
      if (generation != _generation) throw _cancelled;
      if (_loaded.length >= 3) {
        _loaded.remove(_loaded.keys.first)?.runtime.close();
      }
      final result = (runtime: runtime, sources: sources);
      _loaded[id] = result;
      health[id] = 'ok';
      return result;
    } catch (_) {
      runtime.close();
      if (generation == _generation) health[id] = 'failed';
      rethrow;
    } finally {
      _loading.remove(runtime);
    }
  }

  Future<T> _bounded<T>(
    Future<T> future,
    LxRuntime runtime,
    DateTime until,
    Duration maximum,
  ) {
    final remaining = until.difference(DateTime.now());
    final duration = remaining < maximum
        ? (remaining.isNegative ? Duration.zero : remaining)
        : maximum;
    return future.timeout(
      duration,
      onTimeout: () {
        runtime.close();
        _loaded.removeWhere((_, loaded) => identical(loaded.runtime, runtime));
        throw const ApiFailure(
          kind: ApiFailureKind.timeout,
          code: 'DIRECT_LX_TIMEOUT',
          message: '音源解析超时，请重试或更换音源',
        );
      },
    );
  }

  void close() {
    _generation++;
    for (final runtime in _loading) {
      runtime.close();
    }
    _loading.clear();
    for (final loaded in _loaded.values) {
      loaded.runtime.close();
    }
    _loaded.clear();
    health.clear();
  }

  void _requireEdition() {
    if (BuildEdition.isStore) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '此版本不支持本机音源脚本',
      );
    }
  }

  static const _cancelled = ApiFailure(
    kind: ApiFailureKind.invalidConfiguration,
    code: 'DIRECT_SOURCE_CHANGED',
    message: '音源或播放模式已变化，请重试',
  );
}
