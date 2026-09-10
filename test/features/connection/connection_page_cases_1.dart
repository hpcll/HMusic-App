part of 'connection_page_test.dart';

void _connectionPageCases1() {
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
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
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
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
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
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
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
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
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
    final Finder hintFade = find
        .ancestor(
          of: find.text('正在连接上次的服务器…'),
          matching: find.byType(AnimatedOpacity),
        )
        .first;
    expect(tester.widget<AnimatedOpacity>(hintFade).opacity, 0);

    // 1600ms：推到位了（1520ms 落地），这时才开口解释在等什么。
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.widget<AnimatedOpacity>(hintFade).opacity, 1);
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
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
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
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
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
}
