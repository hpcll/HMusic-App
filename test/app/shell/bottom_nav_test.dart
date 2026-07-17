import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/app/shell/bottom_nav.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';

// 悬浮玻璃 dock（Flutter 回退壳）：展开 = 5 tab 等分胶囊条，点 tab 切分支；
// 收缩 = 单枚当前 tab pill，点 pill 只展开、不切 tab（对齐 iOS 26+ 原生壳
// GlassShellOverlay 的收缩语义）。

final GlobalKey<_DockHarnessState> _harnessKey = GlobalKey();

Future<void> _pumpDock(WidgetTester tester) async {
  final router = GoRouter(
    // 初始分支 4 = kNavDestinations 首项「榜单」。
    initialLocation: '/b4',
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
  await tester.pumpWidget(
    MaterialApp.router(theme: HMusicTheme.light(), routerConfig: router),
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
        minimized: minimized,
        onExpand: () => setState(() {
          minimized = false;
          expandCount++;
        }),
      ),
    );
  }
}

void main() {
  testWidgets('展开态渲染 5 tab，点 tab 切换分支', (tester) async {
    await _pumpDock(tester);

    for (final label in <String>['榜单', '搜索', '歌单', '统计', '设置']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('page-4'), findsOneWidget);

    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();
    expect(find.text('page-1'), findsOneWidget);
  });

  testWidgets('收缩态只剩当前 tab pill，点 pill 展开且不切 tab', (tester) async {
    await _pumpDock(tester);
    _harnessKey.currentState!.setMinimized(true);
    await tester.pumpAndSettle();

    expect(find.text('榜单'), findsOneWidget);
    for (final label in <String>['搜索', '歌单', '统计', '设置']) {
      expect(find.text(label), findsNothing);
    }

    await tester.tap(find.text('榜单'));
    await tester.pumpAndSettle();
    expect(_harnessKey.currentState!.expandCount, 1);
    // 展开而非切 tab：5 tab 回来，页面仍是榜单分支。
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('page-4'), findsOneWidget);
  });
}
