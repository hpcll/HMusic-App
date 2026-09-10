import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/app/shell/bottom_nav.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';

// 恢复原四项 dock，保留七分支的页面状态。

final GlobalKey<_DockHarnessState> _harnessKey = GlobalKey();

Future<void> _pumpDock(
  WidgetTester tester, {
  int initialBranch = 4,
  double textScale = 1,
}) async {
  final router = GoRouter(
    initialLocation: '/b$initialBranch',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            _DockHarness(key: _harnessKey, shell: shell),
        branches: <StatefulShellBranch>[
          for (var i = 0; i < 7; i++)
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/b$i',
                  builder: (context, state) => Text('page-$i'),
                ),
              ],
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: HMusicTheme.light(),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
}

class _DockHarness extends StatefulWidget {
  const _DockHarness({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  State<_DockHarness> createState() => _DockHarnessState();
}

class _DockHarnessState extends State<_DockHarness> {
  bool minimized = false;
  int expandCount = 0;

  void setMinimized(bool value) => setState(() => minimized = value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: AppBottomNav(
        shell: widget.shell,
        progress: minimized ? 1 : 0,
        onExpand: () => setState(() {
          minimized = false;
          expandCount++;
        }),
      ),
    );
  }
}

void main() {
  testWidgets('展开态恢复榜单、歌单、统计、设置，点按切换既有分支', (tester) async {
    await _pumpDock(tester);

    for (final label in <String>['榜单', '歌单', '统计', '设置']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('搜索'), findsNothing);
    expect(find.text('page-4'), findsOneWidget);

    await tester.tap(find.text('歌单'));
    await tester.pumpAndSettle();
    expect(find.text('page-3'), findsOneWidget);
  });

  testWidgets('选中药丸随 tab 切换从 A 槽滑到 B 槽', (tester) async {
    await _pumpDock(tester);

    AnimatedAlign pill() => tester.widget<AnimatedAlign>(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.byType(AnimatedAlign),
      ),
    );
    // 初始为榜单入口，药丸停在最左槽位。
    expect(pill().alignment, const Alignment(-1, 0));

    await tester.tap(find.text('歌单'));
    await tester.pumpAndSettle();
    expect(pill().alignment, const Alignment(-1 + 2 / 3, 0));
  });

  testWidgets('收缩态只剩当前 tab 图标圆钮，点圆钮展开且不切 tab', (tester) async {
    await _pumpDock(tester);
    _harnessKey.currentState!.setMinimized(true);
    await tester.pumpAndSettle();

    // 圆钮只留图标，所有标签文字（含当前 tab）都不再渲染。
    for (final label in <String>['榜单', '歌单', '统计', '设置']) {
      expect(find.text(label), findsNothing);
    }
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.local_fire_department_rounded));
    await tester.pumpAndSettle();
    expect(_harnessKey.currentState!.expandCount, 1);
    expect(find.text('歌单'), findsOneWidget);
    expect(find.text('page-4'), findsOneWidget);
  });

  testWidgets('统计分支选中统计，保留正在看的页面', (tester) async {
    await _pumpDock(tester, initialBranch: 5);
    expect(find.text('page-5'), findsOneWidget);
    final pill = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
    expect(pill.alignment, const Alignment(-1 + 4 / 3, 0));
  });

  testWidgets('360 宽两倍文字时 dock 增高且四个入口均可见', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpDock(tester, textScale: 2);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AppBottomNav)).height, greaterThan(62));
    for (final label in <String>['榜单', '歌单', '统计', '设置']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('page-6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
