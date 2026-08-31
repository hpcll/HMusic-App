import 'dart:async';
import 'dart:io';

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
import 'package:hmusic/features/connection/widgets/discovered_server_list.dart';
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
    await _settleOpening(tester);

    // 没有任何点击：地址原样复用，直接落到登录页。
    expect(repository.connectInputs, <String>[
      _FakeConnectionRepository.storedAddress,
    ]);
    expect(find.text('auth destination'), findsOneWidget);
  });

  // 用户反馈：设置页点「更换服务器」只转个圈就回到原页面，服务器永远换不掉；
  // 先退出登录再点也一样（接续成功会把人直接送回登录页）。根因是这页无论从哪
  // 进来都做冷启动接续——原样连回上一台再 go(AuthPage)。换服务器入口带 ?switch=1，
  // 接续必须关掉，人要留在连接页选新的那台。
  testWidgets('从「更换服务器」进来不接续上次的服务器，停在连接页', (tester) async {
    final repository = _FakeConnectionRepository(
      savedAddress: _FakeConnectionRepository.storedAddress,
    );
    final router = _connectRouter(initialLocation: ConnectionPage.switchPath);
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

    // 一次自动连接都不能发起，也不能被弹去登录页。
    expect(repository.connectInputs, isEmpty);
    expect(find.text('auth destination'), findsNothing);
    expect(find.byType(ConnectionPage), findsOneWidget);
    // 主动来换服务器不放开场：不用等那两秒，内容当场就在。
    expect(find.byType(DiscoveredServerList), findsOneWidget);
    // 扫不到东西就展开手输框，并把上次的地址回填进去供修改（只是建议值，不自动连）。
    expect(find.text('连接服务器'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, _FakeConnectionRepository.storedAddress);
  });

  // 用户反馈：开场「好着急，最后一秒出现了重影」。重影来自半路切页——接续在
  // 局域网里两三百毫秒就回来了，那时品牌还在上浮，上一页（已就位）和下一页
  // （还在动）的字标叠着交叉淡入，就成了两个错开的影子。接续再快也要把开场
  // 走完再跳，这条钉的就是「起码等动画完成」。
  testWidgets('接续比开场快：也要等开场走完才跳页', (tester) async {
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

    // 接续早就成功了（假仓库立即返回），但开场没走完，人还得留在这一页——
    // 字标还停在正中（900ms）、乃至刚推到位（1600ms）都不许跳。
    await tester.pump(const Duration(milliseconds: 900));
    expect(repository.connectInputs, isNotEmpty);
    expect(find.text('auth destination'), findsNothing);
    expect(find.byType(ConnectionPage), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('auth destination'), findsNothing);

    await _settleOpening(tester);
    expect(find.text('auth destination'), findsOneWidget);
  });

  // 用户反馈：开 App 时不管登没登录，都要先闪一下「查找服务器」那页，体验不好。
  // 冷启动这一程必须只有品牌：发现卡片、手输框一个都不许在首帧出现；品牌自己
  // 渐显浮上来；接续的那句说明要等 700ms 才淡入——局域网通常几百毫秒就连上了，
  // 一闪而过的菊花反而像出错。
  testWidgets('冷启动开场只显示品牌：不闪查找服务器，说明延迟才出现', (tester) async {
    final Completer<void> gate = Completer<void>();
    final repository = _FakeConnectionRepository(
      savedAddress: _FakeConnectionRepository.storedAddress,
      connectGate: gate.future,
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

    // 首帧：品牌在，且是从透明浮上来的；查找服务器的任何痕迹都不许有。
    expect(find.byType(BrandWordmark), findsOneWidget);
    final Finder brandFade = find
        .ancestor(
          of: find.byType(BrandWordmark),
          matching: find.byType(Opacity),
        )
        .first;
    expect(tester.widget<Opacity>(brandFade).opacity, lessThan(1));
    expect(find.textContaining('正在寻找局域网内'), findsNothing);
    expect(find.text('连接服务器'), findsNothing);
    expect(find.text('手动输入地址'), findsNothing);

    // 800ms：正中的淡入（700ms）已走完，字标满不透明；但它还没被推上去，
    // 所以接续说明仍然不许出声——否则会和停在正中的字标叠在一起。
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.widget<Opacity>(brandFade).opacity, 1);
    expect(find.byType(AnimatedOpacity), findsOneWidget);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      0,
    );

    // 1600ms：推到位了（1520ms 落地），这时才开口解释在等什么。
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
    expect(find.text('正在连接上次的服务器…'), findsOneWidget);

    // 放行接续，收干净计时器与动画（否则测试结束会报未完成的 timer）。
    gate.complete();
    await _settleOpening(tester);
    expect(find.text('auth destination'), findsOneWidget);
  });

  // 用户反馈：「最后搜索的那个页面出来后，能看出来 icon 加文字往上位移了一点」。
  // 原先整列是 Center 居中：开场时列很矮，发现卡片一出现列变高，居中重算就把
  // 品牌块往上顶了一截。品牌钉在视口固定高度处之后，两个状态下它必须在同一位置。
  testWidgets('发现区出现前后，品牌块位置不动', (tester) async {
    final router = _connectRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionRepositoryProvider.overrideWithValue(
            _FakeConnectionRepository(
              savedAddress: _FakeConnectionRepository.storedAddress,
              unreachable: const <String>{
                _FakeConnectionRepository.storedAddress,
              },
            ),
          ),
          lanServerScannerProvider.overrideWithValue(_silentScanner()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // 1600ms：字标已推到位（1520ms 落地），但内容（1700ms 起）还没出现 →
    // 此时量到的就是它的最终位置。
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.byType(DiscoveredServerList), findsNothing);
    final double splashTop = tester.getRect(find.byType(BrandWordmark)).top;

    // 开场结束，发现区显形（假扫描器一无所获，落到空态卡片）。
    await _settleOpening(tester);
    expect(find.byType(DiscoveredServerList), findsOneWidget);
    expect(find.text('没有发现服务器'), findsOneWidget);
    expect(tester.getRect(find.byType(BrandWordmark)).top, splashTop);
  });

  // 用户要的开场：字标先在**屏幕正中**慢慢淡入，再由一个动画把它推到最终位置，
  // 然后下方内容才展现。这条钉住"起点在正中、终点在锚点"这件事——只靠位移实现，
  // 布局槽位全程在终点，所以量的是绘制后的实际矩形。
  testWidgets('第 1 幕字标在屏幕正中，第 2 幕推到锚点', (tester) async {
    final Completer<void> gate = Completer<void>();
    final router = _connectRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionRepositoryProvider.overrideWithValue(
            _FakeConnectionRepository(
              savedAddress: _FakeConnectionRepository.storedAddress,
              connectGate: gate.future,
            ),
          ),
          lanServerScannerProvider.overrideWithValue(_silentScanner()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;

    // 首帧：字标的中心落在屏幕垂直中线上（±1px 容差），而不是最终锚点。
    final Rect atStart = tester.getRect(find.byType(BrandWordmark));
    expect((atStart.center.dy - screen.height / 2).abs(), lessThan(1));

    // 1600ms：推完了（1520ms 落地），字标停在锚点——18% 视口高，明显高于中线。
    await tester.pump(const Duration(milliseconds: 1600));
    final Rect landed = tester.getRect(find.byType(BrandWordmark));
    expect(landed.top, lessThan(atStart.top));
    expect(landed.top, closeTo(screen.height * 0.18, 1));

    gate.complete();
    await _settleOpening(tester);
  });

  // 热启动不放开场：同一个进程里再回到连接页（退出登录、换服务器失败后返回…），
  // 用户点一下按钮不该再等一遍两秒的开场。闸门是 appOpeningProvider，一个
  // ProviderScope 只放一次。
  testWidgets('同一进程第二次进连接页：不放开场', (tester) async {
    final router = _connectRouter();
    addTearDown(router.dispose);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        connectionRepositoryProvider.overrideWithValue(
          _FakeConnectionRepository(),
        ),
        lanServerScannerProvider.overrideWithValue(_silentScanner()),
      ],
    );
    addTearDown(container.dispose);

    // 第一程：开场照放，首帧字标在正中且透明。
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    final Finder brandFade = find
        .ancestor(
          of: find.byType(BrandWordmark),
          matching: find.byType(Opacity),
        )
        .first;
    expect(tester.widget<Opacity>(brandFade).opacity, lessThan(1));
    await _settleOpening(tester);

    // 换一棵树重进这一页（等价于同进程里再次落到 /connect）。
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: const ConnectionPage()),
      ),
    );
    await tester.pump();

    // 闸门已经用掉：字标直接就位、满不透明，内容也不用等。
    expect(tester.widget<Opacity>(brandFade).opacity, 1);
    await tester.pumpAndSettle();
    expect(find.byType(DiscoveredServerList), findsOneWidget);
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
    await _settleOpening(tester);

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
    // 扫描空手而归 → 开场走完后表单经 AnimatedSize 展开，再输入地址。
    await _settleOpening(tester);

    await tester.enterText(
      find.byType(TextField),
      _FakeConnectionRepository.storedAddress,
    );
    // 品牌块钉在视口 30% 处后，800×600 的测试画布上按钮会落到折叠线以下
    // （真机同理：矮屏/开键盘时这页是可滚的），先滚到可见再点。
    await tester.ensureVisible(find.text('连接服务器'));
    await tester.pumpAndSettle();
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
    await _settleOpening(tester);

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
    await _settleOpening(tester);

    expect(find.text('连接服务器'), findsNothing);
    await tester.tap(find.text('手动输入地址'));
    await tester.pumpAndSettle();

    expect(find.text('连接服务器'), findsOneWidget);
    expect(find.text('手动输入地址'), findsNothing);
  });

  // 「更换服务器」有四个入口（窄屏账户卡、设置菜单行、登录页、强制升级页的逃生口）。
  // 漏掉任何一处就是「转个圈又回到原页面」的老毛病在那条路径上复发，而且只有真机
  // 点进去才看得出来。这里按源码机械守一层。
  test('所有「更换服务器」入口都走 switchPath（关掉冷启动接续）', () {
    const List<String> entries = <String>[
      'lib/features/settings/widgets/account_card.dart',
      'lib/features/settings/widgets/server_switch_row.dart',
      'lib/features/auth/views/auth_page.dart',
      'lib/core/upgrade/force_upgrade_page.dart',
    ];
    for (final String path in entries) {
      final String source = File(path).readAsStringSync();
      expect(source, contains('ConnectionPage.switchPath'), reason: path);
      expect(source, isNot(contains('go(ConnectionPage.path)')), reason: path);
    }

    // 上面四处只是带上了参数，真正关掉接续的是路由：漏了这段等于四处白改。
    final String router = File(
      'lib/app/router/app_router.dart',
    ).readAsStringSync();
    expect(router, contains("queryParameters['switch']"));
    expect(router, contains('autoResume:'));
  });
}
