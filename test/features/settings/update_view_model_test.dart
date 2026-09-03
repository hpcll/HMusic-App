import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/models/server_info.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/features/settings/data/api_update_repository.dart';
import 'package:hmusic/features/settings/models/app_update.dart';
import 'package:hmusic/features/settings/view_models/update_view_model.dart';
import 'package:hmusic/shared/models/hmusic_notice.dart';

class _FakeUpdateRepository implements UpdateRepository {
  String version = '0.1.0';
  bool throwOnVersion = false;
  ServerUpdateInfo? serverCheck;
  ApiFailure? serverCheckFailure;
  AppReleaseInfo? appRelease;
  int triggerCalls = 0;

  @override
  Future<String> serverVersion() async {
    if (throwOnVersion) {
      throw const ApiFailure(
        kind: ApiFailureKind.offline,
        message: 'restarting',
      );
    }
    return version;
  }

  @override
  Future<ServerUpdateInfo> checkServer() async {
    final failure = serverCheckFailure;
    if (failure != null) throw failure;
    return serverCheck!;
  }

  @override
  Future<void> triggerServerUpdate() async {
    triggerCalls += 1;
  }

  @override
  Future<AppReleaseInfo?> latestAppRelease() async => appRelease;

  @override
  Future<ServerInfo> serverInfo() async =>
      ServerInfo(name: 'HMusic Server', version: version, apiVersion: 'v1');

  @override
  Future<AppRemoteConfig?> remoteAppConfig() async => null;
}

ProviderContainer _container(_FakeUpdateRepository repository) {
  final container = ProviderContainer(
    overrides: [
      updateRepositoryProvider.overrideWithValue(repository),
      // 检查更新会把版本号记给红点（落盘），内存 store 免掉平台通道。
      keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

const ServerUpdateInfo _newerVersion = ServerUpdateInfo(
  current: '0.1.0',
  latest: 'v0.2.0',
  hasUpdate: true,
  canSelfUpdate: true,
  deployMode: 'native',
  notes: '修复若干问题',
);

void main() {
  // 红点用 AppLifecycleListener 监听「回到前台」，需要 WidgetsBinding。
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isNewerVersion：v 前缀/段数不齐/相等', () {
    expect(isNewerVersion('v0.2.0', '0.1.0'), isTrue);
    expect(isNewerVersion('0.1.1', '0.1.0'), isTrue);
    expect(isNewerVersion('0.1.0', '0.1.0'), isFalse);
    expect(isNewerVersion('0.1.0', '0.2.0'), isFalse);
  });

  test('checkServer：有新版时挂到 state，无提示打扰', () async {
    final repository = _FakeUpdateRepository()..serverCheck = _newerVersion;
    final container = _container(repository);
    final viewModel = container.read(updateViewModelProvider.notifier);

    await viewModel.checkServer();
    final state = container.read(updateViewModelProvider);
    expect(state.serverUpdate?.hasUpdate, isTrue);
    expect(state.serverVersion, '0.1.0');
    expect(state.notice, isNull);
  });

  test('checkServer：已是最新时给成功提示', () async {
    final repository = _FakeUpdateRepository()
      ..serverCheck = const ServerUpdateInfo(
        current: '0.1.0',
        latest: 'v0.1.0',
        hasUpdate: false,
        canSelfUpdate: true,
        deployMode: 'native',
      );
    final container = _container(repository);
    final viewModel = container.read(updateViewModelProvider.notifier);

    await viewModel.checkServer();
    final state = container.read(updateViewModelProvider);
    expect(state.notice?.kind, HMusicNoticeKind.success);
  });

  test('checkServer：检查失败转错误提示', () async {
    final repository = _FakeUpdateRepository()
      ..serverCheckFailure = const ApiFailure(
        kind: ApiFailureKind.server,
        message: '无法连接 GitHub',
      );
    final container = _container(repository);
    final viewModel = container.read(updateViewModelProvider.notifier);

    await viewModel.checkServer();
    expect(
      container.read(updateViewModelProvider).notice?.kind,
      HMusicNoticeKind.error,
    );
  });

  test('checkApp：没有 Release 渠道时给中性提示', () async {
    final repository = _FakeUpdateRepository();
    final container = _container(repository);
    final viewModel = container.read(updateViewModelProvider.notifier);

    await viewModel.checkApp();
    final state = container.read(updateViewModelProvider);
    expect(state.appReleaseChecked, isTrue);
    expect(state.appRelease, isNull);
    expect(state.notice?.kind, HMusicNoticeKind.info);
  });

  test('upgradeServer：触发后轮询 /system/info，版本变化即成功', () {
    fakeAsync((async) {
      final repository = _FakeUpdateRepository()..serverCheck = _newerVersion;
      final container = _container(repository);
      final viewModel = container.read(updateViewModelProvider.notifier);

      var done = false;
      unawaited(viewModel.checkServer().then((_) => done = true));
      async.flushMicrotasks();
      expect(done, isTrue);

      unawaited(viewModel.upgradeServer());
      async.flushMicrotasks();
      expect(repository.triggerCalls, 1);
      expect(container.read(updateViewModelProvider).upgrading, isTrue);

      // 重启窗口内探测失败：保持升级中。
      repository.throwOnVersion = true;
      async.elapse(const Duration(seconds: 7));
      expect(container.read(updateViewModelProvider).upgrading, isTrue);

      // 新版本回来：结束轮询、报成功。
      repository
        ..throwOnVersion = false
        ..version = '0.2.0';
      async.elapse(const Duration(seconds: 4));
      final state = container.read(updateViewModelProvider);
      expect(state.upgrading, isFalse);
      expect(state.serverVersion, '0.2.0');
      expect(state.notice?.kind, HMusicNoticeKind.success);
      expect(state.serverUpdate, isNull);
    });
  });

  test('upgradeServer：超时未见新版本转错误提示并停表', () {
    fakeAsync((async) {
      final repository = _FakeUpdateRepository()..serverCheck = _newerVersion;
      final container = _container(repository);
      final viewModel = container.read(updateViewModelProvider.notifier);

      unawaited(viewModel.checkServer());
      async.flushMicrotasks();
      unawaited(viewModel.upgradeServer());
      async.flushMicrotasks();

      repository.throwOnVersion = true;
      async.elapse(const Duration(minutes: 4));
      final state = container.read(updateViewModelProvider);
      expect(state.upgrading, isFalse);
      expect(state.notice?.kind, HMusicNoticeKind.error);
    });
  });
}
