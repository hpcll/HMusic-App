import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/app/shell/side_navigation_shell.dart';
import 'package:hmusic/app/shell/sidebar.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/features/player/view_models/player_view_model.dart';
import 'package:hmusic/features/settings/view_models/mi_session_watch_view_model.dart';
import 'package:hmusic/shared/layout/shell_metrics.dart';

class _QuietMiSession extends MiSessionWatchViewModel {
  @override
  Future<void> check() async {}
}

Future<void> _pumpSidebar(WidgetTester tester, {required bool rail}) async {
  final router = GoRouter(
    initialLocation: '/b4',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => SideNavigationShell(
          shell: shell,
          mode: rail ? ShellNavigationMode.rail : ShellNavigationMode.sidebar,
          miniActive: false,
        ),
        branches: <StatefulShellBranch>[
          for (var i = 0; i < 7; i++)
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(path: '/b$i', builder: (_, _) => Text('page-$i')),
              ],
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        serverPlaybackStateProvider.overrideWith((ref) => const Stream.empty()),
        miSessionWatchProvider.overrideWith(_QuietMiSession.new),
      ],
      child: MaterialApp.router(
        theme: HMusicTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
      ),
    ),
  );
}

void main() {
  for (final rail in <bool>[true, false]) {
    testWidgets('${rail ? 'rail' : '侧栏'} 矮窗两倍字时七入口均可滚到并激活', (tester) async {
      tester.view.physicalSize = const Size(1024, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        await _pumpSidebar(tester, rail: rail);
        await tester.pumpAndSettle();
        final scrollable = find.descendant(
          of: find.byType(AppSidebar),
          matching: find.byType(Scrollable),
        );
        for (final (label, branch) in <(String, int)>[
          ('搜索', 1),
          ('榜单', 4),
          ('曲库', 3),
          ('听歌统计', 5),
          ('正在播放', 0),
          ('队列', 2),
          ('设置', 6),
        ]) {
          final item = find.byTooltip(label);
          await tester.scrollUntilVisible(item, 80, scrollable: scrollable);
          await tester.pumpAndSettle();
          final data = tester.getSemantics(item).getSemanticsData();
          expect(data.label, label);
          expect(data.hasAction(SemanticsAction.tap), isTrue);
          await tester.tap(item);
          await tester.pumpAndSettle();
          expect(find.text('page-$branch'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      } finally {
        semantics.dispose();
      }
    });
  }
}
