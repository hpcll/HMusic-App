import '../models/hmusic_device.dart';

// 播放设备子域（GET /devices 及三个操作端点）。
abstract interface class DevicesRepository {
  Future<List<HMusicDevice>> getDevices();

  // 从小米账号刷新，返回设备总数。
  Future<int> refresh();

  Future<void> select(String deviceId);

  Future<void> probe(String deviceId);
}
