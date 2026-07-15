import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_controller.dart';
import '../../core/session/session_providers.dart';
import '../../features/auth/views/auth_page.dart';
import '../../features/charts/views/charts_page.dart';
import '../../features/connection/views/connection_page.dart';
import '../../features/player/views/lyrics_page.dart';
import '../../features/player/views/player_page.dart';
import '../../features/playlists/views/playlists_page.dart';
import '../../features/queue/views/queue_page.dart';
import '../../features/search/views/search_page.dart';
import '../../features/settings/views/settings_page.dart';
import '../../features/stats/views/stats_page.dart';
import '../shell/app_shell.dart';

// 路由守卫与跳转集中在这里：ViewModel 只负责业务结果（authenticated / connected），
// 不在多处各自 context.go。SessionController 作为 refreshListenable，
// 401 单飞 invalidate 后重算 redirect 退到登录页。
//
// 结构：connect / auth 为独立全屏页；StatefulShellRoute 7 分支对齐 web 侧栏
// （正在播放/搜索/队列/歌单/榜单/统计/设置）。播放与队列是「双路由」：
//   tabPath 分支 → 桌面侧栏 tab（外壳常驻，内容区切换）；
//   /player、/queue 顶级 push 路由 → 窄屏全屏覆盖（系统返回手势可退出，docs/04 教训）。
// 窄屏永不进这两个分支（mini/入口按宽度分流），桌面永不 push 顶级版。
GoRouter buildAppRouter(Ref ref) {
  final session = ref.read(sessionControllerProvider);
  final refreshNotifier = _SessionRefreshNotifier(session);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: ConnectionPage.path,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final invalid = session.isInvalid;
      final atAuth =
          state.matchedLocation == AuthPage.path ||
          state.matchedLocation == ConnectionPage.path;
      if (invalid && !atAuth) {
        return AuthPage.path;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: ConnectionPage.path,
        builder: (context, state) => const ConnectionPage(),
      ),
      GoRoute(
        path: AuthPage.path,
        builder: (context, state) => const AuthPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: PlayerPage.tabPath,
                builder: (context, state) => const PlayerPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: SearchPage.path,
                builder: (context, state) => const SearchPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: QueuePage.tabPath,
                builder: (context, state) => const QueuePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: PlaylistsPage.path,
                builder: (context, state) => const PlaylistsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: ChartsPage.path,
                builder: (context, state) => const ChartsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: StatsPage.path,
                builder: (context, state) => const StatsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: SettingsPage.path,
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: QueuePage.path,
        builder: (context, state) => const QueuePage(),
      ),
      GoRoute(
        path: PlayerPage.path,
        builder: (context, state) => const PlayerPage(),
      ),
      GoRoute(
        path: LyricsPage.path,
        builder: (context, state) => const LyricsPage(),
      ),
    ],
  );
}

// 把 SessionController 的 ChangeNotifier 桥接成 GoRouter 的 refreshListenable。
// isInvalid 翻转时驱动 redirect 重算，自动退出受保护页。
class _SessionRefreshNotifier extends ChangeNotifier {
  _SessionRefreshNotifier(this._session) {
    _session.addListener(_handleChange);
  }

  final SessionController _session;

  void _handleChange() {
    notifyListeners();
  }

  @override
  void dispose() {
    _session.removeListener(_handleChange);
    super.dispose();
  }
}
