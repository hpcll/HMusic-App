import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/direct/direct_device_registry.dart';
import '../../../core/direct/mi_mina_client.dart';
import '../../../core/direct/playback/direct_playback_repository.dart';
import '../../../core/direct/playback/mi_speaker_commands.dart';
import '../models/hmusic_device.dart';
import 'devices_repository.dart';

class DirectDevicesRepository implements DevicesRepository {
  const DirectDevicesRepository(this._devices, this._playback, this._client);
  final DirectDeviceRegistry _devices;
  final DirectPlaybackRepository _playback;
  final MiMinaClient _client;
  @override
  Future<List<HMusicDevice>> getDevices() async {
    final selected = await _devices.selectedId();
    return [
      HMusicDevice(
        id: HMusicPlaybackState.localDeviceId,
        name: '本机播放',
        type: 'browser',
        isDefault: selected == HMusicPlaybackState.localDeviceId,
        isOnline: _devices.capabilities.supportsLocalPlayback,
      ),
      for (final device in await _devices.devices())
        HMusicDevice(
          id: device.id,
          name: device.name,
          type: 'xiaomi-direct',
          isDefault: device.id == selected,
          isOnline: _devices.isOnline(device.id),
        ),
    ];
  }

  @override
  Future<int> refresh() async => (await _devices.devices(refresh: true)).length;
  @override
  Future<HMusicPlaybackState> select(String deviceId) =>
      _playback.selectDevice(deviceId);
  @override
  Future<void> probe(String deviceId) async {
    final device = await _devices.device(deviceId);
    if (device == null) return;
    await MiSpeakerCommands(
      client: _client,
      instanceId: 'hmusic-direct',
    ).status(await _devices.account.session(), device);
    _devices.confirmOnline(device.id);
  }
}
