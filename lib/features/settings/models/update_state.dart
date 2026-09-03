import '../../../core/app_version.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../models/app_update.dart';

// 「关于与更新」子页状态。upgrading 期间轮询 /system/info 等新版本号回来。
class UpdateState {
  const UpdateState({
    this.serverVersion = '',
    this.serverUpdate,
    this.appRelease,
    this.appReleaseChecked = false,
    this.checkingServer = false,
    this.checkingApp = false,
    this.upgrading = false,
    this.netdiskUrl = kNetdiskDownloadUrl,
    this.notice,
  });

  // 当前连接的服务端版本（进页时从 /system/info 读）。
  final String serverVersion;
  final ServerUpdateInfo? serverUpdate;

  // App 自身最新 Release；checked 且为 null = 仓库还没有 Release。
  final AppReleaseInfo? appRelease;
  final bool appReleaseChecked;
  final bool checkingServer;
  final bool checkingApp;
  final bool upgrading;

  // 网盘下载入口：没梯子的用户查得到新版但下不来（下载直链在 github.com），
  // 这条是那种情况下的退路。默认内置常量，app-config.json 下发的值优先。
  final String netdiskUrl;

  final HMusicNotice? notice;

  UpdateState copyWith({
    String? serverVersion,
    ServerUpdateInfo? serverUpdate,
    AppReleaseInfo? appRelease,
    bool? appReleaseChecked,
    bool? checkingServer,
    bool? checkingApp,
    bool? upgrading,
    String? netdiskUrl,
    HMusicNotice? notice,
    bool clearServerUpdate = false,
    bool clearAppRelease = false,
    bool clearNotice = false,
  }) {
    return UpdateState(
      serverVersion: serverVersion ?? this.serverVersion,
      serverUpdate: clearServerUpdate
          ? null
          : (serverUpdate ?? this.serverUpdate),
      appRelease: clearAppRelease ? null : (appRelease ?? this.appRelease),
      appReleaseChecked: appReleaseChecked ?? this.appReleaseChecked,
      checkingServer: checkingServer ?? this.checkingServer,
      checkingApp: checkingApp ?? this.checkingApp,
      upgrading: upgrading ?? this.upgrading,
      netdiskUrl: netdiskUrl ?? this.netdiskUrl,
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}
