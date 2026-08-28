import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'key_value_store.dart';

/// 默认实现：SharedPreferencesAsync(DataStore) → legacy SharedPreferences → 内存。
KeyValueStore createPreferencesKeyValueStore() {
  return FallbackKeyValueStore(<KeyValueStore>[
    AsyncPreferencesKeyValueStore(),
    LegacyPreferencesKeyValueStore(),
    MemoryKeyValueStore(),
  ]);
}

/// 首选后端：`SharedPreferencesAsync`，Android 上走 DataStore。
class AsyncPreferencesKeyValueStore implements KeyValueStore {
  // 懒构造：SharedPreferencesAsync 的构造函数在平台侧未注册时直接抛 StateError，
  // 放到首次调用里抛才能被 FallbackKeyValueStore 接住并降级。
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _prefs =>
      _preferences ??= SharedPreferencesAsync();

  @override
  Future<String?> getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<double?> getDouble(String key) => _prefs.getDouble(key);

  @override
  Future<void> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// 次选后端：老的 `SharedPreferences`。它在原生侧是另一套 pigeon 通道
/// （SharedPreferencesApi，非 DataStore），首选那条挂掉时它往往还活着。
class LegacyPreferencesKeyValueStore implements KeyValueStore {
  Future<SharedPreferences>? _pending;

  Future<SharedPreferences> get _prefs =>
      _pending ??= SharedPreferences.getInstance();

  @override
  Future<String?> getString(String key) async => (await _prefs).getString(key);

  @override
  Future<void> setString(String key, String value) async =>
      (await _prefs).setString(key, value);

  @override
  Future<double?> getDouble(String key) async => (await _prefs).getDouble(key);

  @override
  Future<void> setDouble(String key, double value) async =>
      (await _prefs).setDouble(key, value);

  @override
  Future<void> remove(String key) async => (await _prefs).remove(key);
}

/// 按顺序降级的组合后端。
///
/// 起因：一位用户点连接页里发现到的服务器，看到红色的 `PlatformException(
/// channel-error, ...SharedPreferencesAsyncApi.getString.data_store)`。服务端其实
/// 已经握手成功（/system/info 校验通过），炸的是紧接着「保存服务器地址」那一步。
/// 原生侧 SharedPreferencesPlugin.setUp() 把通道注册异常吞成一行日志，DataStore
/// 首次访问抛错也只留下 null reply，Dart 侧一律表现为「通道没有处理器」。
/// 本地存储坏掉不该让连接、播放这些主流程失败，所以后端抛平台异常就永久换下一个
/// （重试没意义——坏的是整条通道），最后一层是内存。
class FallbackKeyValueStore implements KeyValueStore {
  FallbackKeyValueStore(this._backends) : assert(_backends.isNotEmpty);

  final List<KeyValueStore> _backends;

  int _current = 0;

  @visibleForTesting
  KeyValueStore get activeBackend => _backends[_current];

  @override
  Future<String?> getString(String key) =>
      _run<String?>((KeyValueStore backend) => backend.getString(key));

  @override
  Future<void> setString(String key, String value) =>
      _run<void>((KeyValueStore backend) => backend.setString(key, value));

  @override
  Future<double?> getDouble(String key) =>
      _run<double?>((KeyValueStore backend) => backend.getDouble(key));

  @override
  Future<void> setDouble(String key, double value) =>
      _run<void>((KeyValueStore backend) => backend.setDouble(key, value));

  @override
  Future<void> remove(String key) =>
      _run<void>((KeyValueStore backend) => backend.remove(key));

  Future<T> _run<T>(Future<T> Function(KeyValueStore backend) action) async {
    // 每次调用自己顺着链条往下走，共享指针只前进不后退：并发的两次调用同时
    // 撞上坏通道时，不会各推一格把中间那层（legacy）整个跳过。
    int index = _current;
    while (true) {
      final KeyValueStore backend = _backends[index];
      try {
        return await action(backend);
      } on Object catch (error, stackTrace) {
        // 不是平台存储故障（或已经退到最后一层）就照原样抛出：这里只负责兜
        // 通道级失效，业务侧的类型错误之类仍应暴露。
        if (!_isPlatformFailure(error) || index >= _backends.length - 1) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        index += 1;
        if (index > _current) {
          _current = index;
          debugPrint(
            '[KeyValueStore] ${backend.runtimeType} 不可用，降级到 '
            '${_backends[index].runtimeType}：$error',
          );
        }
      }
    }
  }

  // StateError 也算：SharedPreferencesAsync 的构造函数在平台实例缺失时抛它。
  static bool _isPlatformFailure(Object error) =>
      error is PlatformException ||
      error is MissingPluginException ||
      error is StateError;
}
