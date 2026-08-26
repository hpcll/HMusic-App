import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_version.dart';
import '../../../core/network/api_failure.dart';
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
    ref.onDispose(_stopPolling);
    return const UpdateState();
  }

  // 进页加载当前服务端版本（公开接口，失败静默——纯展示用）。
  Future<void> load() async {
    try {
      final version = await ref.read(updateRepositoryProvider).serverVersion();
      state = state.copyWith(serverVersion: version);
    } catch (_) {
      // 拿不到就先空着，检查更新时会再报具体错误。
    }
  }

  Future<void> checkServer() async {
    if (state.checkingServer || state.upgrading) return;
    state = state.copyWith(checkingServer: true, clearServerUpdate: true);
    try {
      final info = await ref.read(updateRepositoryProvider).checkServer();
      state = state.copyWith(
        checkingServer: false,
        serverUpdate: info,
        serverVersion: info.current,
        notice: info.hasUpdate ? null : const HMusicNotice.success('服务端已是最新版本'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        checkingServer: false,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  Future<void> checkApp() async {
    if (state.checkingApp) return;
    state = state.copyWith(checkingApp: true, clearAppRelease: true);
    try {
      final release = await ref
          .read(updateRepositoryProvider)
          .latestAppRelease();
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
      state = state.copyWith(
        checkingApp: false,
        appReleaseChecked: true,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  Future<void> upgradeServer() async {
    if (state.upgrading) return;
    final before = state.serverUpdate?.current ?? state.serverVersion;
    state = state.copyWith(upgrading: true);
    try {
      await ref.read(updateRepositoryProvider).triggerServerUpdate();
    } on ApiFailure catch (failure) {
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
