import 'package:shared_preferences/shared_preferences.dart';

import 'local_volume_store.dart';

class SharedPreferencesLocalVolumeStore implements LocalVolumeStore {
  SharedPreferencesLocalVolumeStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _key = 'hmusic.localVolume';

  final SharedPreferencesAsync _preferences;

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
