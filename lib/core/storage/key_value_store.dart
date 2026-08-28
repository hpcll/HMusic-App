/// 本地键值存储的最小契约：服务器地址、升级配置、本机音量三个 store 共用。
///
/// 实现方**不得**因为平台存储故障抛异常：读不到就给 null，写不进就尽力而为。
/// 主流程（连接服务器、播放）不该被本地存储拖死——真实故障见
/// `preferences_key_value_store.dart` 里 FallbackKeyValueStore 的注释。
abstract interface class KeyValueStore {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<double?> getDouble(String key);

  Future<void> setDouble(String key, double value);

  Future<void> remove(String key);
}

/// 进程内兜底：平台存储彻底不可用时，至少让本次会话能正常用（重启回初始状态）。
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, Object> _values = <String, Object>{};

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<double?> getDouble(String key) async => _values[key] as double?;

  @override
  Future<void> setDouble(String key, double value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
