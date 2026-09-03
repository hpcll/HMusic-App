import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/upgrade/apk_updater.dart';
import 'package:hmusic/features/settings/models/app_update.dart';
import 'package:hmusic/features/settings/view_models/app_download_view_model.dart';

const AppReleaseInfo _release = AppReleaseInfo(
  version: 'v0.1.6',
  apkUrl: 'https://example.com/hmusic.apk',
  apkSize: 1000,
);

// 假 updater：把「授权/下载/装包」三步的调用与进度回放攥在手里。
class _FakeUpdater extends ApkUpdater {
  _FakeUpdater({this.permitted = true, this.failWith})
    : super(dio: Dio(), channel: const MethodChannel('test/noop'));

  final bool permitted;
  final Object? failWith;
  bool permissionRequested = false;
  final List<String> installed = <String>[];
  void Function(int received, int total)? progress;

  @override
  Future<bool> canInstall() async => permitted;

  @override
  Future<void> requestInstallPermission() async {
    permissionRequested = true;
  }

  @override
  Future<String> download({
    required String url,
    required String version,
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    progress = onProgress;
    onProgress(500, 1000);
    final failure = failWith;
    if (failure != null) throw failure;
    return '/tmp/hmusic-$version.apk';
  }

  @override
  Future<void> install(String path) async => installed.add(path);
}

ProviderContainer _container(_FakeUpdater updater) {
  final container = ProviderContainer(
    overrides: [apkUpdaterProvider.overrideWithValue(updater)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // 用户要的：点更新不跳 GitHub，就地下载 + 进度条，下完交系统安装器。
  test('下载并安装：进度落到状态里，装包路径交给安装器', () async {
    final updater = _FakeUpdater();
    final container = _container(updater);
    final notifier = container.read(appDownloadViewModelProvider.notifier);

    await notifier.downloadAndInstall(_release);

    expect(updater.installed.single, '/tmp/hmusic-v0.1.6.apk');
    expect(
      container.read(appDownloadViewModelProvider).stage,
      AppDownloadStage.installing,
    );
  });

  test('没给「安装未知应用」授权：先送去开开关，不下载', () async {
    final updater = _FakeUpdater(permitted: false);
    final container = _container(updater);

    await container
        .read(appDownloadViewModelProvider.notifier)
        .downloadAndInstall(_release);

    expect(updater.permissionRequested, isTrue);
    expect(updater.installed, isEmpty);
    final state = container.read(appDownloadViewModelProvider);
    expect(state.stage, AppDownloadStage.failed);
    expect(state.error, contains('安装未知应用'));
  });

  test('下载失败：报原因，不进安装', () async {
    final updater = _FakeUpdater(failWith: const ApkUpdateFailure('下载失败：连接超时'));
    final container = _container(updater);

    await container
        .read(appDownloadViewModelProvider.notifier)
        .downloadAndInstall(_release);

    expect(updater.installed, isEmpty);
    final state = container.read(appDownloadViewModelProvider);
    expect(state.stage, AppDownloadStage.failed);
    expect(state.error, '下载失败：连接超时');
  });

  test('用户取消：回到空闲，不报错', () async {
    final updater = _FakeUpdater(failWith: const ApkUpdateCancelled());
    final container = _container(updater);

    await container
        .read(appDownloadViewModelProvider.notifier)
        .downloadAndInstall(_release);

    final state = container.read(appDownloadViewModelProvider);
    expect(state.stage, AppDownloadStage.idle);
    expect(state.error, isNull);
  });

  test('进度百分比按已收/总字节算，总字节未知时为 null（走不确定条）', () {
    expect(const AppDownloadState(received: 250, total: 1000).progress, 0.25);
    expect(const AppDownloadState(received: 250).progress, isNull);
  });
}
