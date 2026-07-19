import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/app/shell/app_shell.dart';
import 'package:hmusic/app/shell/bottom_nav.dart';

// 壳层返回兜底：非主页 tab 一级页按系统返回先回榜单分支（kHomeBranch），
// 主页再返回才放行冒泡（真机上交还系统退出 App）。
GoRouter _router() {
  return GoRouter(
    initialLocation: '/t1',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            HomeBackFallback(shell: shell, child: shell),
        branches: <StatefulShellBranch>[
          for (var i = 0; i <= kHomeBranch; i++)
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(path: '/t$i', builder: (_, _) => Text('tab$i')),
              ],
            ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('非主页 tab 系统返回先收敛回主页分支，主页再返回才放行', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('tab1'), findsOneWidget);

    // 非主页：返回被拦下并切到主页分支。
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('tab$kHomeBranch'), findsOneWidget);

    // 主页：无可拦截层，放行冒泡（测试环境不真正退出，仍停在主页）。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('tab$kHomeBranch'), findsOneWidget);
  });
}
