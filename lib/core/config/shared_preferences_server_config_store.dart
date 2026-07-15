import 'package:shared_preferences/shared_preferences.dart';

import 'server_config_store.dart';

class SharedPreferencesServerConfigStore implements ServerConfigStore {
  SharedPreferencesServerConfigStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _serverBaseKey = 'hmusic.serverBase';

  final SharedPreferencesAsync _preferences;

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
