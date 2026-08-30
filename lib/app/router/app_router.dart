import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_controller.dart';
import '../../core/session/session_providers.dart';
import '../../core/upgrade/force_upgrade_page.dart';
import '../../core/upgrade/upgrade_gate.dart';
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
// （正在播放/搜索/队列/歌单/榜单/统计/设置）。播放、队列与搜索是「双路由」：
//   tabPath 分支 → 桌面侧栏 tab（外壳常驻，内容区切换）；
//   /player、/queue、/search 顶级 push 路由 → 窄屏全屏覆盖（系统返回手势可退出）。
// 窄屏永不进这三个分支（播放/队列走 mini 入口、搜索走榜单页头胶囊），
// 桌面永不 push 顶级版。
GoRouter buildAppRouter(Ref ref) {
  final session = ref.read(sessionControllerProvider);
  final refreshNotifier = _SessionRefreshNotifier(session);
  ref.onDispose(refreshNotifier.dispose);
  // 强制升级门翻转时驱动 redirect 重算（命中即押入强升页，解除即放行）。
  ref.listen(upgradeGateProvider, (_, __) => refreshNotifier.refresh());

  return GoRouter(
    initialLocation: ConnectionPage.path,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      // 强制升级门优先于会话门：命中后除强升页与连接页（换兼容服务器的
      // 逃生口，页内已先 reset）外全部封锁。
      final gate = ref.read(upgradeGateProvider);
      final atGate = state.matchedLocation == ForceUpgradePage.path;
      if (gate.required && !atGate) {
        return ForceUpgradePage.path;
      }
      if (!gate.required && atGate) {
        // 重新检测通过后放出去（回榜单首页，窄宽两形态都可达）。
        return ChartsPage.path;
      }
      final invalid = session.isInvalid;
      final atAuth =
          state.matchedLocation == AuthPage.path ||
          state.matchedLocation == ConnectionPage.path;
      if (invalid && !atAuth && !atGate) {
        return AuthPage.path;
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: ForceUpgradePage.path,
        builder: (context, state) => const ForceUpgradePage(),
      ),
      GoRoute(
        path: ConnectionPage.path,
        // 只有冷启动落在这条路由上才接续上次的服务器；「更换服务器」入口走
        // ConnectionPage.switchPath（?switch=1），接续必须关掉，否则原样连回
        // 上一台再跳走，用户永远换不成。
        builder: (context, state) => ConnectionPage(
          autoResume: state.uri.queryParameters['switch'] != '1',
        ),
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
                path: SearchPage.tabPath,
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
        path: SearchPage.path,
        builder: (context, state) => const SearchPage(),
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
// isInvalid 翻转时驱动 redirect 重算，自动退出受保护页；升级门翻转走 refresh()。
class _SessionRefreshNotifier extends ChangeNotifier {
  _SessionRefreshNotifier(this._session) {
    _session.addListener(_handleChange);
  }

  final SessionController _session;

  void refresh() => notifyListeners();

  void _handleChange() {
    notifyListeners();
  }

  @override
  void dispose() {
    _session.removeListener(_handleChange);
    super.dispose();
  }
}
