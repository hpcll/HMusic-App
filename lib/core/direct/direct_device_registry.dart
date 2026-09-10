import '../audio/models/hmusic_playback_state.dart';
import '../network/api_failure.dart';
import '../platform/client_playback_capabilities.dart';
import 'mi_direct_account_repository.dart';
import 'mi_direct_device.dart';
import 'music/platform_track_mapper.dart';
import 'storage/direct_local_store.dart';

class DirectDeviceRegistry {
  DirectDeviceRegistry(this.account, this._store, this.capabilities);
  final MiDirectAccountRepository account;
  final DirectLocalStore _store;
  final ClientPlaybackCapabilities capabilities;
  final Map<String, DateTime> _onlineUntil = {};

  bool isOnline(String id) =>
      _onlineUntil[id]?.isAfter(DateTime.now()) ?? false;
  void confirmOnline(String id) =>
      _onlineUntil[id] = DateTime.now().add(const Duration(minutes: 1));

  Future<List<MiDirectDevice>> devices({bool refresh = false}) async {
    var current = account.cachedAccount;
    if (refresh) current = await account.restore();
    if (current != null) {
      await _store.update('devices', (data) {
        data['items'] = [
          for (final device in current!.devices)
            {
              'deviceID': device.id,
              'miotDID': device.did,
              'name': device.name,
              'hardware': device.hardware,
              'ip': device.ip,
            },
        ];
      });
      return _withConfig(current.devices);
    }
    return _withConfig(
      musicRows(
        (await _store.read('devices'))['items'],
      ).map(MiDirectDevice.fromJson).toList(),
    );
  }

  Future<List<MiDirectDevice>> _withConfig(List<MiDirectDevice> devices) async {
    final config = await _store.read('config');
    final models =
        (config['extraPlayMusicModels'] as List?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    return devices.map((device) => device.withExtraModels(models)).toList();
  }

  Future<String> selectedId() async {
    final saved = (await _store.read('devices'))['selectedId'] as String?;
    final available = await devices();
    if (saved == HMusicPlaybackState.localDeviceId &&
        capabilities.supportsLocalPlayback) {
      return saved!;
    }
    if (saved != null && available.any((device) => device.id == saved)) {
      return saved;
    }
    if (capabilities.supportsLocalPlayback) {
      return HMusicPlaybackState.localDeviceId;
    }
    return available.firstOrNull?.id ?? HMusicPlaybackState.localDeviceId;
  }

  Future<void> select(String id) async {
    await device(id);
    await _store.update('devices', (data) {
      data['selectedId'] = id;
    });
  }

  Future<MiDirectDevice?> device(String id) async {
    if (id == HMusicPlaybackState.localDeviceId) {
      capabilities.requireLocalPlayback();
      return null;
    }
    var found = (await devices())
        .where((device) => device.id == id)
        .firstOrNull;
    found ??= (await devices(
      refresh: true,
    )).where((device) => device.id == id).firstOrNull;
    if (found == null) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '音箱已不在设备列表中，请重新选择播放设备',
      );
    }
    return found;
  }
}
