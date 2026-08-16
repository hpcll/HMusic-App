import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/models/server_info.dart';
import 'package:hmusic/core/upgrade/upgrade_gate.dart';
import 'package:hmusic/features/settings/data/api_update_repository.dart';
import 'package:hmusic/features/settings/models/app_update.dart';

class _FakeUpdateRepository implements UpdateRepository {
  ServerInfo? info;
  bool throwOnInfo = false;
  AppRemoteConfig? remoteConfig;

  @override
  Future<ServerInfo> serverInfo() async {
    if (throwOnInfo) throw Exception('offline');
    return info!;
  }

  @override
  Future<AppRemoteConfig?> remoteAppConfig() async => remoteConfig;

  @override
  Future<String> serverVersion() async => info?.version ?? '';

  @override
  Future<ServerUpdateInfo> checkServer() => throw UnimplementedError();

  @override
  Future<void> triggerServerUpdate() => throw UnimplementedError();

  @override
  Future<AppReleaseInfo?> latestAppRelease() async => null;
}

ServerInfo _info(String minAppVersion) => ServerInfo(
  name: 'HMusic Server',
  version: '0.1.0',
  apiVersion: 'v1',
  minAppVersion: minAppVersion,
);

ProviderContainer _container(_FakeUpdateRepository repository) {
  final container = ProviderContainer(
    overrides: [updateRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('服务端 minAppVersion 高于当前版本：封锁并标记来源为服务端', () async {
    final repository = _FakeUpdateRepository()..info = _info('99.0.0');
    final container = _container(repository);

    await container.read(upgradeGateProvider.notifier).check();
    final state = container.read(upgradeGateProvider);
    expect(state.required, isTrue);
    expect(state.fromServer, isTrue);
    expect(state.requiredVersion, '99.0.0');
  });

  test('minAppVersion 为 0.0.0 或空：放行', () async {
    final repository = _FakeUpdateRepository()..info = _info('0.0.0');
    final container = _container(repository);

    await container.read(upgradeGateProvider.notifier).check();
    final state = container.read(upgradeGateProvider);
    expect(state.required, isFalse);
    expect(state.checked, isTrue);
  });

  test('远程配置 minVersion 命中：封锁并带公告与下载地址', () async {
    final repository = _FakeUpdateRepository()
      ..info = _info('')
      ..remoteConfig = const AppRemoteConfig(
        minVersion: '99.0.0',
        notice: '本版本存在严重问题，请务必升级',
        downloadUrl: 'https://example.com/download',
      );
    final container = _container(repository);

    await container.read(upgradeGateProvider.notifier).check();
    final state = container.read(upgradeGateProvider);
    expect(state.required, isTrue);
    expect(state.fromServer, isFalse);
    expect(state.notice, contains('严重问题'));
    expect(state.downloadUrl, 'https://example.com/download');
  });

  test('服务端探测失败 + 无远程配置：放行（门只在明确要求时关）', () async {
    final repository = _FakeUpdateRepository()..throwOnInfo = true;
    final container = _container(repository);

    await container.read(upgradeGateProvider.notifier).check();
    final state = container.read(upgradeGateProvider);
    expect(state.required, isFalse);
    expect(state.checked, isTrue);
  });

  test('reset 清门：换服务器前先放行，待重连后再判', () async {
    final repository = _FakeUpdateRepository()..info = _info('99.0.0');
    final container = _container(repository);
    final gate = container.read(upgradeGateProvider.notifier);

    await gate.check();
    expect(container.read(upgradeGateProvider).required, isTrue);

    gate.reset();
    final state = container.read(upgradeGateProvider);
    expect(state.required, isFalse);
    expect(state.checked, isFalse);
  });
}
