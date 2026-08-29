import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/core/models/server_info.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/features/auth/views/auth_page.dart';
import 'package:hmusic/features/connection/data/api_connection_repository.dart';
import 'package:hmusic/features/connection/data/connection_repository.dart';
import 'package:hmusic/features/connection/data/lan_server_scanner.dart';
import 'package:hmusic/features/connection/models/connection_result.dart';
import 'package:hmusic/features/connection/views/connection_page.dart';
import 'package:hmusic/shared/widgets/brand_mark.dart';

// 页面 initState 会自动扫描：测试必须注入假扫描器，绝不能碰真实网卡/mDNS/网络。
LanServerScanner _silentScanner() => LanServerScanner(
  sweepDelay: Duration.zero,
  mdnsCandidates: () => const Stream<Uri>.empty(),
  localAddresses: () async => const <String>[],
  probe: (_) async => throw Exception('unreachable'),
);

class _FakeConnectionRepository implements ConnectionRepository {
  _FakeConnectionRepository({
    this.savedAddress,
    this.unreachable = const <String>{},
  });

  static const String storedAddress = 'http://192.168.1.10:8090';

  // null = 从未连过服务器（开屏不会有冷启动接续），非 null = 上次连过的地址。
  final String? savedAddress;

  // 连不通的地址：模拟「存过地址但服务端没开/换了网」，接续应静默回落到自动发现。
  final Set<String> unreachable;
  final List<String> connectInputs = <String>[];

  @override
  Future<ConnectionResult> connect(String input) async {
    connectInputs.add(input);
    if (unreachable.contains(input)) {
      throw const ApiFailure(kind: ApiFailureKind.offline, message: '无法连接到服务器');
    }
    return ConnectionResult(
      serverBase: Uri.parse(input),
      serverInfo: const ServerInfo(
        name: 'HMusic Server',
        version: '0.1.0',
        apiVersion: 'v1',
      ),
    );
  }

  @override
  Future<String?> loadSavedAddress() async => savedAddress;
}

GoRouter _connectRouter() => GoRouter(
  initialLocation: ConnectionPage.path,
  routes: <RouteBase>[
    GoRoute(
      path: ConnectionPage.path,
      builder: (context, state) => const ConnectionPage(),
    ),
    GoRoute(
      path: AuthPage.path,
      builder: (context, state) =>
          const Scaffold(body: Text('auth destination')),
    ),
  ],
);

void main() {
  // 冷启动接续：存过地址就直接连回去并进登录页，用户不必每次开 App 重新点服务器
  // ——地址形态和上次存的不一致时 connect() 会当成换服务器清 token，那就等于
  // 「每次打开都要重新登录」。
  testWidgets('冷启动自动接续上次的服务器并进入登录页', (tester) async {
    final repository = _FakeConnectionRepository(
      savedAddress: _FakeConnectionRepository.storedAddress,
    );
    final router = _connectRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionRepositoryProvider.overrideWithValue(repository),
          lanServerScannerProvider.overrideWithValue(_silentScanner()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // 没有任何点击：地址原样复用，直接落到登录页。
    expect(repository.connectInputs, <String>[
      _FakeConnectionRepository.storedAddress,
    ]);
    expect(find.text('auth destination'), findsOneWidget);
  });

  testWidgets('shows server connection form and restores address', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionRepositoryProvider.overrideWithValue(
            // 存过地址但连不通（换网/服务端没开）：接续失败要静默回落到发现 + 手输。
            _FakeConnectionRepository(
              savedAddress: _FakeConnectionRepository.storedAddress,
              unreachable: const <String>{
                _FakeConnectionRepository.storedAddress,
              },
            ),
          ),
          lanServerScannerProvider.overrideWithValue(_silentScanner()),
        ],
        child: const MaterialApp(home: ConnectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 品牌位是完整字标图（字形含 H + Music），页面不再有 "HMusic" 文本。
    expect(find.byType(BrandWordmark), findsOneWidget);
    expect(find.text('连接服务器'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'http://192.168.1.10:8090');
  });

  testWidgets('connect button submits address and navigates to auth', (
    tester,
  ) async {
    final repository = _FakeConnectionRepository();
    final router = _connectRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionRepositoryProvider.overrideWithValue(repository),
          lanServerScannerProvider.overrideWithValue(_silentScanner()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    // 扫描空手而归 → 表单经 AnimatedSize 展开，settle 走完再输入地址。
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      _FakeConnectionRepository.storedAddress,
    );
    await tester.tap(find.text('连接服务器'));
    await tester.pumpAndSettle();

    expect(repository.connectInputs, <String>['http://192.168.1.10:8090']);
    expect(find.text('auth destination'), findsOneWidget);
  });

  testWidgets('自动扫描发现的服务器点选即连并导航', (tester) async {
    final repository = _FakeConnectionRepository();
    // 只有 .11 是 HMusic Server，其余候选一律探不通。
    final scanner = LanServerScanner(
      sweepDelay: Duration.zero,
      mdnsCandidates: () => const Stream<Uri>.empty(),
      localAddresses: () async => const <String>['192.168.31.99'],
      probe: (base) async {
        if (base.host == '192.168.31.11') {
          return <String, Object?>{
            'name': 'HMusic Server',
            'version': '0.1.0',
            'apiVersion': 'v1',
          };
        }
        throw Exception('offline');
      },
    );
    final router = GoRouter(
      initialLocation: ConnectionPage.path,
      routes: <RouteBase>[
        GoRoute(
          path: ConnectionPage.path,
          builder: (context, state) => const ConnectionPage(),
        ),
        GoRoute(
          path: AuthPage.path,
          builder: (context, state) =>
              const Scaffold(body: Text('auth destination')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionRepositoryProvider.overrideWithValue(repository),
          lanServerScannerProvider.overrideWithValue(scanner),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // 层级翻转：有发现结果时表单收起，只留「手动输入地址」链接。
    expect(find.text('192.168.31.11:6650'), findsOneWidget);
    expect(find.text('连接服务器'), findsNothing);
    expect(find.text('手动输入地址'), findsOneWidget);

    await tester.tap(find.text('192.168.31.11:6650'));
    await tester.pumpAndSettle();

    expect(repository.connectInputs, <String>['http://192.168.31.11:6650']);
    expect(find.text('auth destination'), findsOneWidget);
  });

  testWidgets('有发现结果时点「手动输入地址」展开表单', (tester) async {
    final scanner = LanServerScanner(
      sweepDelay: Duration.zero,
      mdnsCandidates: () =>
          Stream<Uri>.fromIterable(<Uri>[Uri.parse('http://10.0.0.7:8090')]),
      localAddresses: () async => const <String>[],
      probe: (base) async => <String, Object?>{
        'name': 'HMusic Server',
        'version': '0.1.0',
        'apiVersion': 'v1',
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionRepositoryProvider.overrideWithValue(
            _FakeConnectionRepository(),
          ),
          lanServerScannerProvider.overrideWithValue(scanner),
        ],
        child: const MaterialApp(home: ConnectionPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('连接服务器'), findsNothing);
    await tester.tap(find.text('手动输入地址'));
    await tester.pumpAndSettle();

    expect(find.text('连接服务器'), findsOneWidget);
    expect(find.text('手动输入地址'), findsNothing);
  });
}
