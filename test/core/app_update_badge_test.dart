import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/app_version.dart';
import 'package:hmusic/core/models/server_info.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/core/upgrade/app_update_badge.dart';
import 'package:hmusic/features/settings/data/api_update_repository.dart';
import 'package:hmusic/features/settings/models/app_update.dart';

// 用户反馈：「只有我点了检查更新才能发现有更新，app 自己其实没有这个发现」。
// 红点这一路必须自己查：开 App 查一次，回到前台且节流窗口过了再查一次，
// 结果落盘（离线也记得上次发现的新版）。
class _CountingRepository implements UpdateRepository {
  _CountingRepository({this.latest = 'v9.9.9'});

  final String latest;
  int calls = 0;

  @override
  Future<AppReleaseInfo?> latestAppRelease() async {
    calls += 1;
    return AppReleaseInfo(version: latest);
  }

  @override
  Future<String> serverVersion() async => '0.2.3';

  @override
  Future<ServerInfo> serverInfo() async =>
      const ServerInfo(name: 's', version: '0.2.3', apiVersion: 'v1');

  @override
  Future<ServerUpdateInfo> checkServer() async => throw UnimplementedError();

  @override
  Future<void> triggerServerUpdate() async => throw UnimplementedError();

  @override
  Future<AppRemoteConfig?> remoteAppConfig() async => null;
}

ProviderContainer _container(
  _CountingRepository repository,
  KeyValueStore store,
) {
  final container = ProviderContainer(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      updateRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // AppLifecycleListener（「回到前台再查一次」用）需要 WidgetsBinding。
  TestWidgetsFlutterBinding.ensureInitialized();

  test('开 App 自己查一次：查到更新的版本就点红点，并落盘', () async {
    final repository = _CountingRepository();
    final store = MemoryKeyValueStore();
    final container = _container(repository, store);

    container.read(appUpdateBadgeProvider);
    await Future<void>.delayed(Duration.zero);

    expect(repository.calls, 1);
    expect(container.read(appUpdateBadgeProvider), 'v9.9.9');
    expect(
      container.read(appUpdateBadgeProvider.notifier).hasUpdate,
      isTrue,
      reason: '当前版本 $kAppVersion 比 v9.9.9 旧',
    );
    expect(await store.getString('hmusic.appUpdate.latest'), 'v9.9.9');
  });

  test('节流窗口内不再打网络，但红点仍从盘里读回来', () async {
    final repository = _CountingRepository();
    final store = MemoryKeyValueStore();
    await store.setString('hmusic.appUpdate.latest', 'v9.9.9');
    await store.setDouble(
      'hmusic.appUpdate.checkedAt',
      DateTime.now().millisecondsSinceEpoch.toDouble(),
    );
    final container = _container(repository, store);

    container.read(appUpdateBadgeProvider);
    await Future<void>.delayed(Duration.zero);

    expect(repository.calls, 0);
    expect(container.read(appUpdateBadgeProvider.notifier).hasUpdate, isTrue);
  });

  test('已是最新：不点红点', () async {
    final repository = _CountingRepository(latest: 'v$kAppVersion');
    final container = _container(repository, MemoryKeyValueStore());

    container.read(appUpdateBadgeProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(appUpdateBadgeProvider.notifier).hasUpdate, isFalse);
  });

  // 别处（关于页进页静默加载 / 手动检查）拿到版本号后记账，不再各查一遍。
  test('noteVersion 记账即点红点，并刷新节流时间', () async {
    final repository = _CountingRepository();
    final store = MemoryKeyValueStore();
    final container = _container(repository, store);
    container.read(appUpdateBadgeProvider);
    await Future<void>.delayed(Duration.zero);
    final callsAfterBoot = repository.calls;

    await container
        .read(appUpdateBadgeProvider.notifier)
        .noteVersion('v9.9.10');

    expect(container.read(appUpdateBadgeProvider), 'v9.9.10');
    expect(repository.calls, callsAfterBoot, reason: 'noteVersion 不该再发请求');
    expect(await store.getString('hmusic.appUpdate.latest'), 'v9.9.10');
  });
}
