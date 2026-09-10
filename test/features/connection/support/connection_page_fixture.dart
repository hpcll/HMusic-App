part of '../connection_page_test.dart';

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
    this.connectGate,
  });

  static const String storedAddress = 'http://192.168.1.10:8090';

  // null = 从未连过服务器（开屏不会有冷启动接续），非 null = 上次连过的地址。
  final String? savedAddress;

  // 连不通的地址：模拟「存过地址但服务端没开/换了网」，接续应静默回落到自动发现。
  final Set<String> unreachable;

  // 连接挂起不返回：复刻「接续还在路上」的那段时间窗，用来验开场的分帧表现。
  final Future<void>? connectGate;

  final List<String> connectInputs = <String>[];

  @override
  Future<ConnectionResult> connect(String input) async {
    connectInputs.add(input);
    if (connectGate != null) await connectGate;
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

GoRouter _connectRouter({String? initialLocation}) => GoRouter(
  initialLocation: initialLocation ?? ConnectionPage.path,
  routes: <RouteBase>[
    GoRoute(
      path: ConnectionPage.path,
      builder: (context, state) => ConnectionPage(
        autoResume: state.uri.queryParameters['switch'] != '1',
      ),
    ),
    GoRoute(
      path: AuthPage.path,
      builder: (context, state) =>
          const Scaffold(body: Text('auth destination')),
    ),
  ],
);

// 三幕开场共 1900ms（正中淡入 700 → 停 300 → 推到位 520 → 标语/内容），
// 走完控件才出现、接续成功也才跳页。这里显式把时钟推过整段开场。
Future<void> _settleOpening(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 2000));
  await tester.pumpAndSettle();
}
