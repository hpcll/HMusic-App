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
import 'package:hmusic/features/connection/widgets/server_address_form.dart';
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
    expect(find.text('没有发现服务器'), findsOneWidget);
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

  // 新版开场分幕重叠：内容在字标上移途中就开始浮出，不再有「内容未出现」的
  // 干净采样点。退而钉死「字标的布局槽恒定」：落位帧（1350ms，lift 结束）量
  // 到的位置，与开场走完、发现区显形后必须一致——内容怎么变，品牌块都不会
  // 被顶动（顶对齐 + transform 只动绘制不动布局）。
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

    // 1350ms：字标落位（lift 1350 结束），发现区正在淡入（1100 起）。
    await tester.pump(const Duration(milliseconds: 1350));
    final double lockedTop = tester.getRect(find.byType(BrandWordmark)).top;

    // 开场结束，发现区显形（假扫描器一无所获 → 空态：提示 + 自动展开表单）。
    await _settleOpening(tester);
    expect(find.byType(ServerAddressForm), findsOneWidget);
    expect(find.text('没有发现服务器'), findsOneWidget);
    expect(tester.getRect(find.byType(BrandWordmark)).top, lockedTop);
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
    expect(find.text('没有发现服务器'), findsOneWidget);
  });

  // 页脚注脚是压在滚动视图之上的一块装饰（Stack + Positioned）。它的 hairline
  // 是 ColoredBox（命中行为 opaque）、标语是 RenderParagraph（hitTestSelf 恒真），
  // 不套 IgnorePointer 的话从注脚这一带起手就拖不动页面——矮屏/开键盘时这页是
  // 可滚的，而拇指最自然的起手位置正是屏幕底缘。
  testWidgets('注脚不吃手势：从注脚上起手照样能滚动', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionRepositoryProvider.overrideWithValue(
            _FakeConnectionRepository(),
          ),
          lanServerScannerProvider.overrideWithValue(_silentScanner()),
        ],
        child: const MaterialApp(home: ConnectionPage()),
      ),
    );
    await _settleOpening(tester);

    // 手输框内部也有个 Scrollable（EditableText），要的是页面那一层。
    final ScrollableState scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(scrollable.position.pixels, 0);

    await tester.drag(
      find.text('你的音乐，在你的服务器上'),
      const Offset(0, -120),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
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

    // 骨架恒定：发现卡内出结果，手动表单原位不动。
    expect(find.text('192.168.31.11:6650'), findsOneWidget);
    expect(find.text('连接服务器'), findsOneWidget);

    await tester.tap(find.text('192.168.31.11:6650'));
    await tester.pumpAndSettle();

    expect(repository.connectInputs, <String>['http://192.168.31.11:6650']);
    expect(find.text('auth destination'), findsOneWidget);
  });

  testWidgets('手动表单恒可见：有结果时也无需展开', (tester) async {
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

    // 表单永远在场：有发现结果时也直接可见，不再折叠成链接。
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

  // 注脚遇到键盘要让位：输入框聚焦（页面层用 FocusNode 驱动，不碰 viewInsets
  // ——body 里被 Scaffold 摘掉，页面层读则键盘动画逐帧重建整页会抖）。
  // 否则输入框聚焦、视口被压缩，注脚会被顶上来正好叠在延迟最高的「连接服务器」
  // 按钮上——真机反馈「脚注和那条线被键盘推上来了」。焦点一收回注脚就要回来。
  testWidgets('输入框聚焦时注脚让位，失焦后回来', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionRepositoryProvider.overrideWithValue(
            _FakeConnectionRepository(),
          ),
          lanServerScannerProvider.overrideWithValue(_silentScanner()),
        ],
        child: const MaterialApp(home: ConnectionPage()),
      ),
    );
    await _settleOpening(tester);
    expect(find.text('你的音乐，在你的服务器上'), findsOneWidget);

    // 点输入框：键盘即将弹起（聚焦信号先行），注脚立即让位。
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(find.text('你的音乐，在你的服务器上'), findsNothing);
    // 表单本体不受影响。
    expect(find.text('连接服务器'), findsOneWidget);

    // 失焦（键盘收起）：注脚回来。
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.text('你的音乐，在你的服务器上'), findsOneWidget);
  });

  // 用户反馈：键盘弹出时整页抖动。v1 的两个根因都已修掉：几何基准随 body
  // 收缩走（已改用键盘免疫的 viewPadding）、内容子树写在 LayoutBuilder 闭包里
  // 随 body 逐帧重建（已外提）。所以现在直接用 Scaffold 默认的
  // resizeToAvoidBottomInset：键盘只压缩滚动视口，未聚焦就不滚动。此测试复刻
  // insets 逐帧上报 + padding 被蚕食的完整序列，任何一帧几何都不许动。
  testWidgets('键盘弹起时品牌块与内容位置纹丝不动', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionRepositoryProvider.overrideWithValue(
            _FakeConnectionRepository(),
          ),
          lanServerScannerProvider.overrideWithValue(_silentScanner()),
        ],
        child: const MaterialApp(home: ConnectionPage()),
      ),
    );
    await _settleOpening(tester);

    // 手势条在场（真实手机形态），几何基准要含它。改过的 view 状态测完必须
    // 还原，否则残留的 insets 会让后面的键盘用例读到「键盘在降」。
    addTearDown(tester.view.reset);
    tester.view.padding = const FakeViewPadding(bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    await tester.pump();

    final double brandTopBefore = tester
        .getTopLeft(find.byType(BrandWordmark))
        .dy;
    final double buttonTopBefore = tester.getTopLeft(find.text('连接服务器')).dy;

    // 复刻真机键盘弹起的完整序列：insets 逐帧上报 + padding 被蚕食到 0（viewPadding
    // 恒定不动）。几何基准取 viewPadding、输入框未聚焦，所以任何一帧都不许动。
    for (final double inset in <double>[40, 120, 240, 320]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      tester.view.padding = FakeViewPadding(
        bottom: inset >= 24 ? 0 : 24 - inset,
      );
      await tester.pump(const Duration(milliseconds: 33));
      expect(tester.getTopLeft(find.byType(BrandWordmark)).dy, brandTopBefore);
      expect(tester.getTopLeft(find.text('连接服务器')).dy, buttonTopBefore);
    }
  });

  // 键盘让位（用户反馈「输入时看不到输入框」+「两段式不丝滑」）：走 Flutter
  // 标准机制——Scaffold 随键盘逐帧收缩 body，EditableText 每个 metrics 节拍把
  // 光标连同 scrollPadding 划出的矩形滚进视口。ServerAddressForm 把
  // scrollPadding.bottom 一路算到连接按钮下缘 + 16，输入框和按钮一起抬上来；
  // 键盘收起视口恢复，滚动区自动钳回，不需要任何手写恢复逻辑。
  testWidgets('键盘弹起后输入框与连接按钮抬到键盘上方，收起回位', (tester) async {
    // dpr=1：viewInsets/尺寸直接按逻辑像素算，好断言。760 高：内容装得下
    // （max=0），对应真机形态——收起后滚动区钳回 0 就是原位；内容装不下的
    // 矮屏收起后停在最近的合法位置，不主动跳回顶部（标准行为，不另钉）。
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 760);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionRepositoryProvider.overrideWithValue(
            _FakeConnectionRepository(),
          ),
          lanServerScannerProvider.overrideWithValue(_silentScanner()),
        ],
        child: const MaterialApp(home: ConnectionPage()),
      ),
    );
    await _settleOpening(tester);
    final double fieldTopBefore = tester.getTopLeft(find.byType(TextField)).dy;

    // 聚焦输入框（键盘开始升）。
    await tester.tap(find.byType(TextField));
    await tester.pump();

    // 键盘 300 高：metrics 一到 body 收缩，EditableText 在 post-frame
    // 里 jumpTo 让位（真机上引擎逐帧同步 insets，每帧都走这一趟）。
    const double keyboardTop = 760 - 300;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump(); // metrics → body 收缩 + 让位调度
    await tester.pump(); // post-frame jumpTo 落地
    await tester.pumpAndSettle();

    // 输入框在键盘上方；连接按钮下缘恰好落在键盘上缘之上 16——少了被吞，
    // 多了就是用户反馈过的「推太高」。
    expect(
      tester.getRect(find.byType(TextField)).bottom,
      lessThanOrEqualTo(keyboardTop),
    );
    expect(
      tester.getRect(find.byType(FilledButton)).bottom,
      closeTo(keyboardTop - 16, 2),
    );

    // 收起：视口恢复，滚动余量归零，内容被钳回原位。
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(TextField)).dy, fieldTopBefore);
  });

  // 让位期间不许重排：内容的高度只跟键盘免疫的 viewportHeight 有关，键盘一来
  // 只有视口变矮、滚动余量长出键盘那么高。此前滚动区的最小高度跟着 body 约束
  // 走（LayoutBuilder），键盘每一帧都把整列重排一次——真机上就是让位/滚动的
  // 掉帧。内容高度 = maxScrollExtent + viewportDimension，键盘前后必须相等。
  testWidgets('键盘让位只改视口不改内容高度，余量恰好长出键盘那么高', (tester) async {
    // 1000 高：内容装得下，最小高度真正起作用（内容比视口高时两种写法
    // 都取自然高度，看不出差别）。
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionRepositoryProvider.overrideWithValue(
            _FakeConnectionRepository(),
          ),
          lanServerScannerProvider.overrideWithValue(_silentScanner()),
        ],
        child: const MaterialApp(home: ConnectionPage()),
      ),
    );
    await _settleOpening(tester);

    ScrollPosition position() => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    final double contentBefore =
        position().maxScrollExtent + position().viewportDimension;
    final double extentBefore = position().maxScrollExtent;

    await tester.tap(find.byType(TextField));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      position().maxScrollExtent + position().viewportDimension,
      closeTo(contentBefore, 0.5),
    );
    expect(position().maxScrollExtent - extentBefore, closeTo(300, 0.5));

    // 内容整列自成一层：让位/滚动每帧只把这一层按新偏移合成，不重跑整列的
    // paint，也让引擎的 raster cache 留得住栅格结果。
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });

  // 用户反馈：发现区三态（扫描中/空态/有结果）结构互跳，表单跟着上下蹿。
  // 现在骨架恒定：发现卡定高、内部换内容，表单永远在卡下方原位。
  testWidgets('扫描中转空态：输入框与按钮位置纹丝不动', (tester) async {
    final Completer<List<String>> sweepGate = Completer<List<String>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionRepositoryProvider.overrideWithValue(
            _FakeConnectionRepository(),
          ),
          lanServerScannerProvider.overrideWithValue(
            // 扫段被 gate 卡住 → 这一趟扫不完，一直显示「正在寻找」；放行 = 扫完。
            LanServerScanner(
              sweepDelay: Duration.zero,
              mdnsCandidates: () => const Stream<Uri>.empty(),
              localAddresses: () => sweepGate.future,
              probe: (_) async => throw Exception('unreachable'),
            ),
          ),
        ],
        child: const MaterialApp(home: ConnectionPage()),
      ),
    );
    // 扫描中菊花一直在转，pumpAndSettle 到不了静止，全程改用固定时钟推进。
    await tester.pump(const Duration(milliseconds: 2500)); // 走过开场与提示延时

    // 表单恒在，直接记录位置。
    expect(find.text('正在寻找局域网内的服务器'), findsOneWidget);

    final double fieldTopBefore = tester.getTopLeft(find.byType(TextField)).dy;
    final double buttonTopBefore = tester.getTopLeft(find.text('连接服务器')).dy;

    // 这一趟扫完：一无所获，发现卡内换字，卡与表单几何不动。
    sweepGate.complete(const <String>[]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('没有发现服务器'), findsOneWidget);

    expect(tester.getTopLeft(find.byType(TextField)).dy, fieldTopBefore);
    expect(tester.getTopLeft(find.text('连接服务器')).dy, buttonTopBefore);
  });
}
