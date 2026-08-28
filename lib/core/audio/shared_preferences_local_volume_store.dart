import '../storage/key_value_store.dart';
import '../storage/preferences_key_value_store.dart';
import 'local_volume_store.dart';

class SharedPreferencesLocalVolumeStore implements LocalVolumeStore {
  SharedPreferencesLocalVolumeStore({KeyValueStore? preferences})
    : _preferences = preferences ?? createPreferencesKeyValueStore();

  static const String _key = 'hmusic.localVolume';

  final KeyValueStore _preferences;

  @override
  Future<double> read() async {
    final value = await _preferences.getDouble(_key);
    return (value ?? 1).clamp(0, 1).toDouble();
  }

  @override
  Future<void> write(double volume) {
    return _preferences.setDouble(_key, volume.clamp(0, 1).toDouble());
  }
}
