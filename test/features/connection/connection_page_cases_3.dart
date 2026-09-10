part of 'connection_page_test.dart';

void _connectionPageCases3() {
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
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
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
  // 让位是淡出而非摘出树：收键盘的瞬间 body 还在收缩中，若瞬时就地渲染，注脚
  // 会先压在连接按钮的位置闪一下 hairline，再随 body 展开落回页底（真机反馈
  // 「收起键盘时那条白线在连接按钮上闪一下」）。淡出让它在下落途中才显形。
  testWidgets('输入框聚焦时注脚让位，失焦后回来', (tester) async {
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
    final Finder footnoteFade = find
        .ancestor(
          of: find.text('你的音乐，在你的服务器上'),
          matching: find.byType(AnimatedOpacity),
        )
        .first;
    expect(tester.widget<AnimatedOpacity>(footnoteFade).opacity, 1);

    // 点输入框：键盘即将弹起（聚焦信号先行），注脚让位（淡出）。
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(footnoteFade).opacity, 0);
    // 表单本体不受影响。
    expect(find.text('连接服务器'), findsOneWidget);

    // 失焦（键盘收起）：注脚淡回来。
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(footnoteFade).opacity, 1);
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
    // dpr=1：viewInsets/尺寸直接按逻辑像素算。840 高容纳新增的模式入口
    // （max=0），对应真机形态——收起后滚动区钳回 0 就是原位；内容装不下的
    // 矮屏收起后停在最近的合法位置，不主动跳回顶部（标准行为，不另钉）。
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 840);
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
    final double fieldTopBefore = tester.getTopLeft(find.byType(TextField)).dy;

    // 聚焦输入框（键盘开始升）。
    await tester.tap(find.byType(TextField));
    await tester.pump();

    // 键盘 300 高：metrics 一到 body 收缩，EditableText 在 post-frame
    // 里 jumpTo 让位（真机上引擎逐帧同步 insets，每帧都走这一趟）。
    const double keyboardTop = 840 - 300;
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
}
