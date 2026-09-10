import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_version.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/playback/backend_request.dart';
import '../../../core/playback/playback_mode.dart';
import '../../../core/playback/playback_mode_controller.dart';
import '../../../core/upgrade/app_update_badge.dart';
import '../../../core/upgrade/upgrade_config_store.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../data/api_update_repository.dart';
import '../models/update_state.dart';

final NotifierProvider<UpdateViewModel, UpdateState> updateViewModelProvider =
    NotifierProvider<UpdateViewModel, UpdateState>(UpdateViewModel.new);

// 「关于与更新」：服务端升级检查/一键升级 + App 自身新版检查。
// 一键升级后服务端会停止重启，这里轮询公开的 /system/info 等版本号变化，
// 变了即成功；超时给出看日志的指引（升级脚本日志在服务端 data/update.log）。
class UpdateViewModel extends Notifier<UpdateState> {
  Timer? _pollTimer;

  static const Duration _pollInterval = Duration(seconds: 3);
  static const Duration _pollTimeout = Duration(minutes: 3);

  @override
  UpdateState build() {
    ref.watch(playbackModeProvider);
    ref.onDispose(_stopPolling);
    return const UpdateState();
  }

  // 进页加载：当前服务端版本 + App 新版信息，两路都静默（失败不弹提示——纯展示，
  // 手动点「检查更新」时才报具体错误）。
  //
  // App 新版这一路以前不在这里：于是设置入口都点上红点了，进来还得再点一次
  // 「检查更新」才看得到「下载并安装」。红点说的和这一页说的必须是同一件事。
  Future<void> load() async {
    await Future.wait(<Future<void>>[
      if (ref.read(playbackModeProvider) == PlaybackMode.server)
        _loadServerVersion(),
      loadAppRelease(),
      _loadRemoteLinks(),
    ]);
  }

  // 更新出口地址（网盘 + iOS 的 App Store 链接）：app-config.json（三镜像 +
  // 服务端中转）下发的优先，拉不到就用上次落盘的那份。网盘还有内置常量兜底，
  // iOS 链接没有——没上架时 iOS 端本来就不给下载动作，这条退路恰恰在网络
  // 最差时才被用到，不能反过来依赖网络。
  Future<void> _loadRemoteLinks() async {
    final request = BackendRequest(ref);
    try {
      final config =
          await ref.read(updateRepositoryProvider).remoteAppConfig() ??
          await ref.read(upgradeConfigStoreProvider).read();
      if (config == null || !request.current) return;
      final netdisk = config.netdiskUrl ?? '';
      if (netdisk.isNotEmpty) state = state.copyWith(netdiskUrl: netdisk);
      final ios = config.iosUrl ?? '';
      if (ios.isNotEmpty) state = state.copyWith(iosUrl: ios);
    } catch (_) {
      // 保持内置常量 / 空链接。
    }
  }

  Future<void> _loadServerVersion() async {
    final request = BackendRequest(ref);
    try {
      final version = await ref.read(updateRepositoryProvider).serverVersion();
      if (!request.current) return;
      state = state.copyWith(serverVersion: version);
    } catch (_) {
      // 拿不到就先空着，检查更新时会再报具体错误。
    }
  }

  Future<void> loadAppRelease() async {
    final request = BackendRequest(ref);
    if (state.checkingApp) return;
    try {
      final release = await ref
          .read(updateRepositoryProvider)
          .latestAppRelease();
      if (!request.current) return;
      state = state.copyWith(appRelease: release, appReleaseChecked: true);
      // 顺手把版本号记给红点，省掉它自己再发一次请求。
      await ref
          .read(appUpdateBadgeProvider.notifier)
          .noteVersion(release?.version ?? '');
    } catch (_) {
      // 静默：这一路是进页面顺手拉的，失败不该弹错误。
    }
  }

  Future<void> checkServer() async {
    if (ref.read(playbackModeProvider) != PlaybackMode.server) return;
    final request = BackendRequest(ref);
    if (state.checkingServer || state.upgrading) return;
    state = state.copyWith(checkingServer: true, clearServerUpdate: true);
    try {
      final info = await ref.read(updateRepositoryProvider).checkServer();
      if (!request.current) return;
      state = state.copyWith(
        checkingServer: false,
        serverUpdate: info,
        serverVersion: info.current,
        notice: info.hasUpdate ? null : const HMusicNotice.success('服务端已是最新版本'),
      );
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(
        checkingServer: false,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  Future<void> checkApp() async {
    final request = BackendRequest(ref);
    if (state.checkingApp) return;
    state = state.copyWith(checkingApp: true, clearAppRelease: true);
    try {
      final release = await ref
          .read(updateRepositoryProvider)
          .latestAppRelease();
      if (!request.current) return;
      await ref
          .read(appUpdateBadgeProvider.notifier)
          .noteVersion(release?.version ?? '');
      if (!request.current) return;
      state = state.copyWith(
        checkingApp: false,
        appRelease: release,
        appReleaseChecked: true,
        notice: release == null
            ? const HMusicNotice('还没有发布下载渠道，当前就是最新')
            : release.hasUpdateOver(kAppVersion)
            ? null
            : const HMusicNotice.success('App 已是最新版本'),
      );
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(
        checkingApp: false,
        appReleaseChecked: true,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  Future<void> upgradeServer() async {
    if (ref.read(playbackModeProvider) != PlaybackMode.server) return;
    final request = BackendRequest(ref);
    if (state.upgrading) return;
    final before = state.serverUpdate?.current ?? state.serverVersion;
    state = state.copyWith(upgrading: true);
    try {
      await ref.read(updateRepositoryProvider).triggerServerUpdate();
      if (!request.current) return;
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(
        upgrading: false,
        notice: HMusicNotice.error(failure.message),
      );
      return;
    }
    _pollUntilVersionChanges(before);
  }

  // 每 3s 探一次 /system/info：重启窗口内请求失败属正常，静默继续；
  // 版本号变化 = 升级完成；超时不代表失败（弱设备 npm install 可能很慢），
  // 提示去看服务端日志。按轮询次数计超时（不依赖真实时钟，可测）。
  void _pollUntilVersionChanges(String before) {
    final request = BackendRequest(ref);
    _stopPolling();
    final maxTicks =
        _pollTimeout.inMilliseconds ~/ _pollInterval.inMilliseconds;
    var ticks = 0;
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      ticks += 1;
      try {
        final version = await ref
            .read(updateRepositoryProvider)
            .serverVersion();
        if (!request.current) return;
        if (version.isNotEmpty && version != before) {
          _stopPolling();
          state = state.copyWith(
            upgrading: false,
            serverVersion: version,
            clearServerUpdate: true,
            notice: HMusicNotice.success('服务端已升级到 v$version'),
          );
          return;
        }
      } catch (_) {
        // 服务端正在重启，下一轮再探。
      }
      if (ticks >= maxTicks) {
        if (!request.current) return;
        _stopPolling();
        state = state.copyWith(
          upgrading: false,
          notice: const HMusicNotice.error(
            '升级还没结束（可能仍在进行）。稍后手动检查版本，或查看服务端 data/update.log',
          ),
        );
      }
    });
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}
