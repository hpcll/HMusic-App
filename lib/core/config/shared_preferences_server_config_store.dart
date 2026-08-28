import '../storage/key_value_store.dart';
import '../storage/preferences_key_value_store.dart';
import 'server_config_store.dart';

class SharedPreferencesServerConfigStore implements ServerConfigStore {
  SharedPreferencesServerConfigStore({KeyValueStore? preferences})
    : _preferences = preferences ?? createPreferencesKeyValueStore();

  static const _serverBaseKey = 'hmusic.serverBase';

  final KeyValueStore _preferences;

  @override
  Future<void> clear() => _preferences.remove(_serverBaseKey);

  @override
  Future<Uri?> read() async {
    final value = await _preferences.getString(_serverBaseKey);
    return value == null ? null : Uri.tryParse(value);
  }

  @override
  Future<void> write(Uri serverBase) {
    return _preferences.setString(_serverBaseKey, serverBase.toString());
  }
}
