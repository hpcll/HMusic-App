import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/core/storage/preferences_key_value_store.dart';

/// 使用正式平台存储通道，但测试键与所有用户业务键隔离，且不允许降级为内存。
class NativeVerificationStore implements KeyValueStore {
  NativeVerificationStore(String runId)
    : _prefix = 'hmusic.verification.process.$runId.';
  final String _prefix;
  final _store = AsyncPreferencesKeyValueStore();
  @override
  Future<String?> getString(String key) => _store.getString('$_prefix$key');
  @override
  Future<void> setString(String key, String value) =>
      _store.setString('$_prefix$key', value);
  @override
  Future<double?> getDouble(String key) => _store.getDouble('$_prefix$key');
  @override
  Future<void> setDouble(String key, double value) =>
      _store.setDouble('$_prefix$key', value);
  @override
  Future<void> remove(String key) => _store.remove('$_prefix$key');
}
