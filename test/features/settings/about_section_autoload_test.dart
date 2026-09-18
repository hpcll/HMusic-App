import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/models/server_info.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/features/settings/data/api_update_repository.dart';
import 'package:hmusic/features/settings/models/app_update.dart';
import 'package:hmusic/features/settings/view_models/update_view_model.dart';
import 'package:hmusic/features/settings/widgets/sections/about_section.dart';

// 用户反馈：「就算设置按钮有红点了，进入更新页面还是要手动点检查更新才会出现
// 下载并安装按钮」。进页面就该把 App 新版信息静默拉进来——红点说的和这一页
// 说的必须是同一件事。
class _FakeUpdateRepository implements UpdateRepository {
  _FakeUpdateRepository({this.remoteConfig});

  // remoteAppConfig 的返回值；null 时给默认网盘配置（非 iOS 路径用）。
  final AppRemoteConfig? remoteConfig;

  int appReleaseCalls = 0;

  @override
  Future<AppReleaseInfo?> latestAppRelease() async {
    appReleaseCalls += 1;
    return const AppReleaseInfo(
      version: 'v9.9.9',
      notes: '新版说明',
      url: 'https://example.com/releases/tag/v9.9.9',
      apkUrl: 'https://example.com/hmusic.apk',
      apkSize: 26000000,
    );
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
  Future<AppRemoteConfig?> remoteAppConfig() async =>
      remoteConfig ??
      const AppRemoteConfig(netdiskUrl: 'https://pan.quark.cn/s/mirror');
}

void main() {
  testWidgets('进「关于与更新」不用点检查更新：新版信息与更新按钮自己出来', (tester) async {
    final repository = _FakeUpdateRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateRepositoryProvider.overrideWithValue(repository),
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AboutSectionView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.appReleaseCalls, 1, reason: '进页面就该静默拉一次');
    expect(find.text('发现新版本 v9.9.9'), findsOneWidget);
    expect(find.text('新版说明'), findsOneWidget);
    // 直装渠道（Android 非商店）出「下载并安装」，其余平台出「去下载」。
    // 单测跑在 host 平台上，两者取其一即可——关键是按钮不用先点检查更新才出现。
    expect(
      find.text('下载并安装').evaluate().length + find.text('去下载').evaluate().length,
      1,
    );
  });

  // 没梯子的用户查得到新版却下不来（下载直链在 github.com）：网盘入口必须常驻，
  // 且地址跟随 app-config.json 下发（换链接不用发新版）。
  testWidgets('关于页常驻网盘入口，地址取 app-config 下发的值', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateRepositoryProvider.overrideWithValue(_FakeUpdateRepository()),
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AboutSectionView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('从网盘下载'), findsOneWidget);
    final netdiskButton = find.ancestor(
      of: find.text('从网盘下载'),
      matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
    );
    expect(netdiskButton, findsOneWidget);
    expect(tester.getSize(netdiskButton).height, greaterThanOrEqualTo(48));
    expect(find.byIcon(Icons.cloud_download_outlined), findsOneWidget);
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final launches = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      launches.add(call);
      return true;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });
    await tester.ensureVisible(netdiskButton);
    await tester.tap(netdiskButton);
    await tester.pump();
    expect(launches.single.method, 'launch');
    expect(
      (launches.single.arguments as Map)['url'],
      'https://pan.quark.cn/s/mirror',
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AboutSectionView)),
      listen: false,
    );
    expect(
      container.read(updateViewModelProvider).netdiskUrl,
      'https://pan.quark.cn/s/mirror',
    );
  });

  // iOS 没有 APK 自装通道：未上架（iosUrl 空）时不给任何下载按钮、也不露
  // 网盘入口（网盘里是安卓/ipa 装包，装不上 iPhone），只说明分发渠道。
  testWidgets('iOS 未上架：无下载按钮无网盘入口，说明走 App Store', (tester) async {
    // 平台覆盖必须在测试体内复位（try/finally）——binding 的 invariant 检查
    // 跑在 tearDown 之前，挂到 addTearDown 会报 debug 变量被改。
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateRepositoryProvider.overrideWithValue(_FakeUpdateRepository()),
            keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: AboutSectionView()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('发现新版本 v9.9.9'), findsOneWidget);
      expect(find.text('下载并安装'), findsNothing);
      expect(find.text('去下载'), findsNothing);
      expect(find.textContaining('App Store'), findsOneWidget);
      expect(find.textContaining('从网盘下载'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // 上架后 iosUrl 由 app-config.json 下发：按钮直达 App Store，网盘入口仍隐藏。
  testWidgets('iOS 已上架：按钮直达 App Store，网盘入口隐藏', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updateRepositoryProvider.overrideWithValue(
              _FakeUpdateRepository(
                remoteConfig: const AppRemoteConfig(
                  netdiskUrl: 'https://pan.quark.cn/s/mirror',
                  iosUrl: 'https://apps.apple.com/cn/app/id1234',
                ),
              ),
            ),
            keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: AboutSectionView()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('去 App Store 更新'), findsOneWidget);
      expect(find.textContaining('从网盘下载'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AboutSectionView)),
        listen: false,
      );
      expect(
        container.read(updateViewModelProvider).iosUrl,
        'https://apps.apple.com/cn/app/id1234',
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
