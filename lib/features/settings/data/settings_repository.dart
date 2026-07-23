import '../../../core/audio/models/hmusic_playback_state.dart';
import '../models/server_config.dart';
import '../models/settings_summary.dart';

// 设置中心聚合仓库：菜单摘要 + 运行配置 + 链路诊断 + 改密码。
// 设备/音源/小米账号等独立子域各有专属 repository。
abstract interface class SettingsRepository {
  Future<SettingsSummary> loadSummary();

  Future<ServerConfig> getConfig();

  // 传 null 的字段不下发（PATCH 子集语义）；manualTracks 全量替换。
  Future<ServerConfig> patchConfig({
    String? serverName,
    String? defaultQuality,
    String? searchStrategy,
    String? resolveStrategy,
    List<String>? extraPlayMusicModels,
    List<ManualTrack>? manualTracks,
    bool? announceTracks,
  });

  // 诊断页 3s 轮询用：直接问 Server，不经 AudioHandler。
  Future<HMusicPlaybackState> getPlaybackState();

  Future<void> playTestTone();

  Future<void> speak(String text);

  // 成功后新 token 已写入 TokenStore，调用方无需重登。
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  // 删除账户（App Store 合规）：校验密码后服务端物理清除全部数据并回到未初始化态。
  // 成功后调用方须清 token + 会话失效回登录/setup。
  Future<void> deleteAccount({required String password});
}
