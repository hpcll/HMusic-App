import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/build_edition.dart';
import '../../../core/upgrade/apk_updater.dart';
import '../models/app_update.dart';

// App 自更新的下载/安装状态机（只在 Android 直装渠道用）。
// idle → downloading(progress) → installing（系统安装器已弹出）；失败带原因。
enum AppDownloadStage { idle, downloading, installing, failed }

class AppDownloadState {
  const AppDownloadState({
    this.stage = AppDownloadStage.idle,
    this.received = 0,
    this.total = 0,
    this.error,
  });

  final AppDownloadStage stage;
  final int received;
  final int total;
  final String? error;

  bool get busy =>
      stage == AppDownloadStage.downloading ||
      stage == AppDownloadStage.installing;

  // 总字节未知（服务端没给 content-length）时返回 null → 进度条走不确定态。
  double? get progress {
    if (total <= 0) return null;
    return (received / total).clamp(0.0, 1.0);
  }
}

// 自更新是否走 App 内下载：商店版交给商店更新（Play 政策不允许自装），
// 非 Android 平台没有直装通道。两种情况都退回「去下载」跳浏览器。
bool get canSelfInstallApp => apkSelfUpdateSupported && !BuildEdition.isStore;

final NotifierProvider<AppDownloadViewModel, AppDownloadState>
appDownloadViewModelProvider =
    NotifierProvider<AppDownloadViewModel, AppDownloadState>(
      AppDownloadViewModel.new,
    );

class AppDownloadViewModel extends Notifier<AppDownloadState> {
  CancelToken? _cancelToken;

  @override
  AppDownloadState build() {
    ref.onDispose(() => _cancelToken?.cancel());
    return const AppDownloadState();
  }

  // 下载并交给系统安装器。安装未知应用没授权时先把用户送去开开关，回来再点。
  Future<void> downloadAndInstall(AppReleaseInfo release) async {
    final url = release.apkUrl;
    if (url == null || url.isEmpty || state.busy) return;
    final updater = ref.read(apkUpdaterProvider);
    if (!await updater.canInstall()) {
      await updater.requestInstallPermission();
      state = const AppDownloadState(
        stage: AppDownloadStage.failed,
        error: '需要允许「安装未知应用」，开完再点一次更新',
      );
      return;
    }
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = AppDownloadState(
      stage: AppDownloadStage.downloading,
      total: release.apkSize ?? 0,
    );
    try {
      final path = await updater.download(
        url: url,
        version: release.version,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          if (state.stage != AppDownloadStage.downloading) return;
          state = AppDownloadState(
            stage: AppDownloadStage.downloading,
            received: received,
            total: total > 0 ? total : state.total,
          );
        },
      );
      state = const AppDownloadState(stage: AppDownloadStage.installing);
      await updater.install(path);
    } on ApkUpdateCancelled {
      state = const AppDownloadState();
    } on ApkUpdateFailure catch (failure) {
      state = AppDownloadState(
        stage: AppDownloadStage.failed,
        error: failure.message,
      );
    } on Exception catch (error) {
      state = AppDownloadState(stage: AppDownloadStage.failed, error: '$error');
    } finally {
      _cancelToken = null;
    }
  }

  void cancel() {
    _cancelToken?.cancel();
    _cancelToken = null;
    if (state.stage == AppDownloadStage.downloading) {
      state = const AppDownloadState();
    }
  }
}
