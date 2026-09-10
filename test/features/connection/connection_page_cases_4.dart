part of 'connection_page_test.dart';

void _connectionPageCases4() {
  testWidgets('键盘让位只改视口不改内容高度，余量恰好长出键盘那么高', (tester) async {
    // 1000 高：内容装得下，最小高度真正起作用（内容比视口高时两种写法
    // 都取自然高度，看不出差别）。
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.reset);
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
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
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
