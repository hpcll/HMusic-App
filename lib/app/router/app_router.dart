import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/direct/auth/mi_web_verifier.dart';
import '../../core/direct/direct_session_providers.dart';
import '../../core/platform_shell/shell_navigation.dart';
import '../../core/playback/playback_mode.dart';
import '../../core/playback/playback_mode_controller.dart';
import '../../core/session/session_controller.dart';
import '../../core/session/session_providers.dart';
import '../../core/upgrade/force_upgrade_page.dart';
import '../../core/upgrade/upgrade_gate.dart';
import '../../features/auth/views/auth_page.dart';
import '../../features/charts/views/charts_page.dart';
import '../../features/connection/views/connection_page.dart';
import '../../features/direct_auth/views/direct_login_page.dart';
import '../../features/direct_auth/views/direct_verification_page.dart';
import '../../features/player/views/lyrics_page.dart';
import '../../features/player/views/player_page.dart';
import '../../features/queue/views/queue_page.dart';
import '../../features/search/views/search_page.dart';
import '../../features/settings/models/settings_section.dart';
import '../../features/settings/views/settings_page.dart';
import '../../features/stats/views/stats_page.dart';
import '../shell/app_shell.dart';
import '../shell/library_stats_page.dart';
import '../views/music_library_page.dart';
import '../views/playback_settings_page.dart';
import 'output_picker_page.dart';

// 路由守卫与跳转集中在这里：ViewModel 只负责业务结果（authenticated / connected），
// 不在多处各自 context.go。SessionController 作为 refreshListenable，
// 401 单飞 invalidate 后重算 redirect 退到登录页。
//
// 结构：connect / auth 为独立全屏页；StatefulShellRoute 7 分支对齐 web 侧栏
// （正在播放/搜索/队列/歌单/榜单/统计/设置）。播放、队列与搜索是「双路由」：
//   tabPath 分支 → 桌面侧栏 tab（外壳常驻，内容区切换）；
//   /player、/queue、/search 顶级 push 路由 → 窄屏全屏覆盖（系统返回手势可退出）。
// 窄屏入口使用覆盖页，宽屏入口使用分支；窗口缩窄仍保留当前分支页面。
GoRouter buildAppRouter(Ref ref) {
  final session = ref.read(sessionControllerProvider);
  final refreshNotifier = _SessionRefreshNotifier(session);
  ref.onDispose(refreshNotifier.dispose);
  // 强制升级门翻转时驱动 redirect 重算（命中即押入强升页，解除即放行）。
  ref.listen(upgradeGateProvider, (_, __) => refreshNotifier.refresh());
  ref.listen(playbackModeProvider, (_, __) => refreshNotifier.refresh());
  final directSession = ref.watch(directSessionControllerProvider);
  directSession.addListener(refreshNotifier.refresh);
  ref.onDispose(() => directSession.removeListener(refreshNotifier.refresh));

  return GoRouter(
    initialLocation: ConnectionPage.path,
    refreshListenable: refreshNotifier,
    redirect: (context, state) => _redirectForState(ref, session, state),
    routes: <RouteBase>[
      ..._entryRoutes(),
      _mainShellRoute(),
      ..._overlayRoutes(),
    ],
  );
}

String? _redirectForState(
  Ref ref,
  SessionController session,
  GoRouterState state,
) {
  final mode = ref.read(playbackModeProvider);
  if (mode == PlaybackMode.player) {
    return const [
          ConnectionPage.path,
          AuthPage.path,
          DirectLoginPage.path,
          DirectVerificationPage.path,
          ForceUpgradePage.path,
          kOutputPickerPath,
        ].contains(state.matchedLocation)
        ? ChartsPage.path
        : null;
  }
  if (mode == PlaybackMode.direct) {
    final atLogin =
        state.matchedLocation == DirectLoginPage.path ||
        state.matchedLocation == DirectVerificationPage.path;
    if (!atLogin &&
        (ref.read(directSessionControllerProvider).isInvalid ||
            state.matchedLocation == ConnectionPage.path ||
            state.matchedLocation == AuthPage.path ||
            state.matchedLocation == ForceUpgradePage.path)) {
      return DirectLoginPage.path;
    }
    return null;
  }
  if (state.matchedLocation == DirectLoginPage.path ||
      state.matchedLocation == DirectVerificationPage.path) {
    return ConnectionPage.path;
  }
  // 强制升级门优先于会话门；连接页换兼容服务器时会先 reset 升级门。
  final gate = ref.read(upgradeGateProvider);
  final atGate = state.matchedLocation == ForceUpgradePage.path;
  if (gate.required && !atGate) return ForceUpgradePage.path;
  if (!gate.required && atGate) return ChartsPage.path;
  final atAuth =
      state.matchedLocation == AuthPage.path ||
      state.matchedLocation == ConnectionPage.path;
  if (session.isInvalid && !atAuth && !atGate) return AuthPage.path;
  return null;
}

List<RouteBase> _entryRoutes() => <RouteBase>[
  GoRoute(
    path: DirectVerificationPage.path,
    redirect: (_, state) =>
        state.extra is MiWebAuthRequest ? null : DirectLoginPage.path,
    pageBuilder: (_, state) => NoTransitionPage<MiWebAuthResult>(
      key: state.pageKey,
      child: DirectVerificationPage(request: state.extra! as MiWebAuthRequest),
    ),
  ),
  GoRoute(
    path: DirectLoginPage.path,
    pageBuilder: (context, state) => _fadePage(state, const DirectLoginPage()),
  ),
  GoRoute(
    path: ForceUpgradePage.path,
    builder: (context, state) => const ForceUpgradePage(),
  ),
  GoRoute(
    path: ConnectionPage.path,
    // 冷启动才接续上次服务器；更换服务器的 ?switch=1 关闭自动接续。
    pageBuilder: (context, state) => _fadePage(
      state,
      ConnectionPage(autoResume: state.uri.queryParameters['switch'] != '1'),
    ),
  ),
  GoRoute(
    path: AuthPage.path,
    pageBuilder: (context, state) => _fadePage(state, const AuthPage()),
  ),
];

// 七分支顺序是历史路由合同，手机入口的归属不改变此表。
StatefulShellRoute _mainShellRoute() => StatefulShellRoute.indexedStack(
  builder: (context, state, shell) => AppShell(navigationShell: shell),
  branches: <StatefulShellBranch>[
    _pageBranch(PlayerPage.tabPath, const PlayerPage()),
    _pageBranch(SearchPage.tabPath, const SearchPage()),
    _pageBranch(QueuePage.tabPath, const QueuePage()),
    _pageBranch(MusicLibraryPage.path, const MusicLibraryPage()),
    _pageBranch(ChartsPage.path, const ChartsPage()),
    _pageBranch(StatsPage.path, const LibraryStatsPage()),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: SettingsPage.path,
          builder: (_, state) => PlaybackSettingsPage(
            initialSection: state.uri.queryParameters['section'] == 'sources'
                ? SettingsSection.sources
                : null,
          ),
        ),
      ],
    ),
  ],
);

StatefulShellBranch _pageBranch(String path, Widget child) =>
    StatefulShellBranch(
      routes: <RouteBase>[
        GoRoute(path: path, builder: (context, state) => child),
      ],
    );

List<RouteBase> _overlayRoutes() => <RouteBase>[
  GoRoute(
    path: kOutputPickerPath,
    pageBuilder: (context, state) => OutputPickerPage(key: state.pageKey),
  ),
  GoRoute(path: QueuePage.path, builder: (context, state) => const QueuePage()),
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
];

// 开场三连跳（连接页 →登录页 →token 有效则首页）用淡入淡出，不用平台默认的
// 滑入：两页的品牌块位置、尺寸完全一致，且都处于静止态，淡入淡出下字标看着是
// 定在原地的；滑入则把它演成三次翻页。450ms 对齐 clearshot 那套 600ms 级别的
// 转场——260ms 那档太急，交叉淡入还没稳住就结束了。减动效环境直接给结果。
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        MediaQuery.disableAnimationsOf(context)
        ? child
        : FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          ),
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
