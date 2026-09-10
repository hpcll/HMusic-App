part of 'connection_page_test.dart';

void _connectionPageCases2() {
  testWidgets('同一进程第二次进连接页：不放开场', (tester) async {
    final router = _connectRouter();
    addTearDown(router.dispose);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
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
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
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
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
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
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
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
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
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
}
