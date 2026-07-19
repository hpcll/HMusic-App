import '../../../core/audio/models/hmusic_playback_state.dart';
import '../models/hmusic_device.dart';

// 播放设备子域（GET /devices 及三个操作端点）。
abstract interface class DevicesRepository {
  Future<List<HMusicDevice>> getDevices();

  // 从小米账号刷新，返回设备总数。
  Future<int> refresh();

  // select 返回切换后的播放状态（服务端同时暂停旧设备、更新 deviceId）。
  Future<HMusicPlaybackState> select(String deviceId);

  Future<void> probe(String deviceId);
}
