import '../storage/key_value_store.dart';
import '../storage/preferences_key_value_store.dart';

import 'playback_mode.dart';

/// 只存模式选择；直连凭证由后续 DirectAuthRepository 使用安全存储保存。
class PlaybackModeStore {
  PlaybackModeStore({KeyValueStore? preferences})
    : _preferences = preferences ?? createPreferencesKeyValueStore();

  static const key = 'hmusic.playback_mode';
  final KeyValueStore _preferences;

  Future<PlaybackMode> read() async {
    return PlaybackModeWire.parse(await _preferences.getString(key));
  }

  Future<void> write(PlaybackMode mode) async {
    await _preferences.setString(key, mode.wireName);
  }

  Future<void> clear() async {
    await _preferences.remove(key);
  }
}
