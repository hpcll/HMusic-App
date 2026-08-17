import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/models/server_info.dart';
import 'package:hmusic/core/upgrade/upgrade_config_store.dart';
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

class _MemoryUpgradeConfigStore implements UpgradeConfigStore {
  AppRemoteConfig? saved;

  @override
  Future<AppRemoteConfig?> read() async => saved;

  @override
  Future<void> write(AppRemoteConfig config) async => saved = config;
}

ServerInfo _info(String minAppVersion) => ServerInfo(
  name: 'HMusic Server',
  version: '0.1.0',
  apiVersion: 'v1',
  minAppVersion: minAppVersion,
);

ProviderContainer _container(
  _FakeUpdateRepository repository, {
  _MemoryUpgradeConfigStore? store,
}) {
  final container = ProviderContainer(
    overrides: [
      updateRepositoryProvider.overrideWithValue(repository),
      upgradeConfigStoreProvider.overrideWithValue(
        store ?? _MemoryUpgradeConfigStore(),
      ),
    ],
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

  test('远程配置在线取到即落盘（粘性执行的来源）', () async {
    final store = _MemoryUpgradeConfigStore();
    final repository = _FakeUpdateRepository()
      ..info = _info('')
      ..remoteConfig = const AppRemoteConfig(minVersion: '99.0.0');
    final container = _container(repository, store: store);

    await container.read(upgradeGateProvider.notifier).check();
    expect(store.saved?.minVersion, '99.0.0');
  });

  test('拉不到配置但本地有旧配置：照样执行强制（断网躲不掉）', () async {
    final store = _MemoryUpgradeConfigStore()
      ..saved = const AppRemoteConfig(
        minVersion: '99.0.0',
        notice: '此前下发的强制升级',
      );
    final repository = _FakeUpdateRepository()..info = _info('');
    final container = _container(repository, store: store);

    await container.read(upgradeGateProvider.notifier).check();
    final state = container.read(upgradeGateProvider);
    expect(state.required, isTrue);
    expect(state.notice, contains('此前下发'));
  });

  test('拉不到配置且本地无缓存：放行（只影响从未收到过配置的安装）', () async {
    final repository = _FakeUpdateRepository()..info = _info('');
    final container = _container(repository);

    await container.read(upgradeGateProvider.notifier).check();
    expect(container.read(upgradeGateProvider).required, isFalse);
  });

  test('新配置覆盖旧缓存：下发更低 minVersion 可解除历史强制', () async {
    final store = _MemoryUpgradeConfigStore()
      ..saved = const AppRemoteConfig(minVersion: '99.0.0');
    final repository = _FakeUpdateRepository()
      ..info = _info('')
      ..remoteConfig = const AppRemoteConfig(minVersion: '0.0.0');
    final container = _container(repository, store: store);

    await container.read(upgradeGateProvider.notifier).check();
    expect(container.read(upgradeGateProvider).required, isFalse);
    expect(store.saved?.minVersion, '0.0.0');
  });

  test('服务端 403 拒绝老版本：当场关门，不等下一轮自检', () async {
    final repository = _FakeUpdateRepository()..info = _info('0.0.0');
    final container = _container(repository);
    final gate = container.read(upgradeGateProvider.notifier);

    await gate.check();
    expect(container.read(upgradeGateProvider).required, isFalse);

    gate.rejectedByServer('9.0.0');
    final state = container.read(upgradeGateProvider);
    expect(state.required, isTrue);
    expect(state.fromServer, isTrue);
    expect(state.requiredVersion, '9.0.0');
  });

  test('403 未带版本号也能关门（展示退化为「更高版本」）', () async {
    final repository = _FakeUpdateRepository()..info = _info('0.0.0');
    final container = _container(repository);

    container.read(upgradeGateProvider.notifier).rejectedByServer('');
    final state = container.read(upgradeGateProvider);
    expect(state.required, isTrue);
    expect(state.requiredVersion, '更高版本');
  });
}
