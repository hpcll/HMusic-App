import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/charts/views/charts_page.dart';
import '../../features/player/view_models/player_view_model.dart';
import '../../features/player/views/player_page.dart';
import '../../features/playlists/views/playlists_page.dart';
import '../../features/search/views/search_page.dart';
import '../../features/settings/views/settings_page.dart';
import '../../features/stats/views/stats_page.dart';
import 'platform_shell_bridge.dart';

// tab id ↔ 路由 ↔ 标题的唯一映射，顺序与 bottom_nav 窄屏 5 tab 一致。
// Swift dock 与 Flutter 底栏共用这套 id，原生 selectTab intent 的 value 必须在此表内。
const List<(String id, String path, String title)> kShellTabs =
    <(String, String, String)>[
      ('charts', ChartsPage.path, '榜单'),
      ('search', SearchPage.path, '搜索'),
      ('playlists', PlaylistsPage.path, '歌单'),
      ('stats', StatsPage.path, '统计'),
      ('settings', SettingsPage.path, '设置'),
    ];

// Dart 侧 chrome 桥接与 intent 派发的单一出口：原生层只回传语义 intent，
// 这里翻译成 Router/PlayerViewModel 调用。Swift 不持有业务状态，intent 必须回到这里。
// 职责：路由变化 → updateNavigation/updateLayout；播放流 → updateNowPlaying；
// 原生 ready/layoutChanged → 暴露给 AppShell 决定是否隐藏 Flutter chrome 并让出 inset。
class PlatformShellController extends ChangeNotifier {
  PlatformShellController({
    required PlatformShellBridge bridge,
    required GoRouter router,
    required PlayerViewModel playerViewModel,
  }) : _bridge = bridge,
       _router = router,
       _playerViewModel = playerViewModel {
    _intentSubscription = _bridge.intents.listen(_handleIntent);
    _readySubscription = _bridge.readyEvents.listen(_onReady);
    _layoutSubscription = _bridge.layoutChanges.listen(_onLayout);
    _router.routerDelegate.addListener(_onRouteChanged);
  }

  final PlatformShellBridge _bridge;
  final GoRouter _router;
  final PlayerViewModel _playerViewModel;

  late final StreamSubscription<ShellIntent> _intentSubscription;
  late final StreamSubscription<ShellReady> _readySubscription;
  late final StreamSubscription<ShellLayout> _layoutSubscription;
  StreamSubscription<MediaItem?>? _mediaItemSubscription;
  StreamSubscription<PlaybackState>? _playbackSubscription;

  bool _disposed = false;
  List<String> _capabilities = const <String>[];
  double _nativeBottomInset = 0;
  MediaItem? _track;
  bool _playing = false;
  bool _scrollMinimized = false;
  (String?, String?, String?, String?, bool)? _sentNowPlaying;
  (String, String, bool)? _sentNavigation;
  (bool, bool)? _sentLayout;

  // 原生壳声明了底栏 + mini player 才算接管；AppShell 据此隐藏 Flutter chrome。
  bool get nativeChromeActive =>
      _capabilities.contains('bottomBar') &&
      _capabilities.contains('miniPlayer');

  // 原生 chrome 占据的底部高度（含安全区），内容滚动区以此让位。
  double get nativeBottomInset => _nativeBottomInset;

  @override
  void dispose() {
    _disposed = true;
    _router.routerDelegate.removeListener(_onRouteChanged);
    unawaited(_intentSubscription.cancel());
    unawaited(_readySubscription.cancel());
    unawaited(_layoutSubscription.cancel());
    unawaited(_mediaItemSubscription?.cancel());
    unawaited(_playbackSubscription?.cancel());
    super.dispose();
  }

  // audio handler 异步初始化完成后接入：mediaItem/playbackState 均为 BehaviorSubject，
  // 订阅即得当前值，原生 mini player 冷启动也能拿到正在播的曲目。
  void attachAudioHandler(BaseAudioHandler handler) {
    if (_disposed) return;
    unawaited(_mediaItemSubscription?.cancel());
    unawaited(_playbackSubscription?.cancel());
    _mediaItemSubscription = handler.mediaItem.listen((item) {
      _track = item;
      _pushNowPlaying();
    });
    _playbackSubscription = handler.playbackState.listen((state) {
      if (state.playing == _playing) return;
      _playing = state.playing;
      _pushNowPlaying();
    });
  }

  Future<void> configure({
    required bool darkMode,
    required bool reduceMotion,
    required bool reduceTransparency,
  }) {
    return _bridge.configure(
      darkMode: darkMode,
      reduceMotion: reduceMotion,
      reduceTransparency: reduceTransparency,
    );
  }

  @visibleForTesting
  void handleIntent(ShellIntent intent) => _handleIntent(intent);

  // 原生壳就绪：记录能力供 AppShell 切换，并全量补发当前状态——
  // ready 可能晚于路由/播放变化（Flutter 引擎先行），不能只靠增量。
  void _onReady(ShellReady ready) {
    _capabilities = ready.capabilities;
    _sentNavigation = null;
    _sentLayout = null;
    _sentNowPlaying = null;
    _onRouteChanged();
    _pushNowPlaying();
    unawaited(
      configure(
        darkMode:
            PlatformDispatcher.instance.platformBrightness == Brightness.dark,
        reduceMotion: false,
        reduceTransparency: false,
      ),
    );
    notifyListeners();
  }

  void _onLayout(ShellLayout layout) {
    if (layout.bottomInset == _nativeBottomInset) return;
    _nativeBottomInset = layout.bottomInset;
    notifyListeners();
  }

  // AppShell 的滚动监听调用：向下滚 → dock 收缩，向上滚 → 展开。
  // 去重后才过桥，滚动事件高频，不能每帧发 channel 消息。
  void reportScroll({required bool minimized}) {
    if (!nativeChromeActive || minimized == _scrollMinimized) return;
    _scrollMinimized = minimized;
    unawaited(_bridge.updateScroll(minimized: minimized));
  }

  // 路由 → chrome 状态：5 个 tab 页显示 dock；player/lyrics/queue/连接/登录等
  // 全屏页整体隐藏。未知路由按无 chrome 处理，宁可少画不可遮挡。
  // 注意取末位 match：imperative push 不改 uri，只在 match 列表尾部追加。
  void _onRouteChanged() {
    final matches = _router.routerDelegate.currentConfiguration.matches;
    final path = matches.isEmpty ? '' : matches.last.matchedLocation;
    String? tabId;
    var title = '';
    for (final (id, tabPath, tabTitle) in kShellTabs) {
      if (path == tabPath) {
        tabId = id;
        title = tabTitle;
        break;
      }
    }
    final isTab = tabId != null;
    final navigation = (tabId ?? '', title, _router.canPop());
    if (navigation != _sentNavigation) {
      _sentNavigation = navigation;
      unawaited(
        _bridge.updateNavigation(
          selectedTab: navigation.$1,
          title: navigation.$2,
          canGoBack: navigation.$3,
        ),
      );
    }
    final layout = (isTab, isTab);
    if (layout != _sentLayout) {
      _sentLayout = layout;
      unawaited(_bridge.updateLayout(showTabBar: isTab, showMiniPlayer: isTab));
    }
  }

  void _pushNowPlaying() {
    final track = _track;
    final snapshot = (
      track?.id,
      track?.title,
      track?.artist,
      track?.artUri?.toString(),
      _playing,
    );
    if (snapshot == _sentNowPlaying) return;
    _sentNowPlaying = snapshot;
    unawaited(
      _bridge.updateNowPlaying(
        trackId: snapshot.$1,
        title: snapshot.$2,
        artist: snapshot.$3,
        artworkUrl: snapshot.$4,
        playing: snapshot.$5,
      ),
    );
  }

  // 语义 intent → 路由/播放命令。seek 与 dismiss 在 P0 忽略并保持静默，
  // 不抛异常以免原生壳崩溃拖垮 Flutter 帧树。
  void _handleIntent(ShellIntent intent) {
    switch (intent.type) {
      case ShellIntentType.selectTab:
        _selectTab(intent.value);
      case ShellIntentType.openNowPlaying:
        unawaited(_router.push(PlayerPage.path));
      case ShellIntentType.playPause:
        unawaited(
          _playing ? _playerViewModel.pause() : _playerViewModel.play(),
        );
      case ShellIntentType.previous:
        unawaited(_playerViewModel.skipToPrevious());
      case ShellIntentType.next:
        unawaited(_playerViewModel.skipToNext());
      case ShellIntentType.seek:
      case ShellIntentType.dismiss:
        break;
    }
  }

  void _selectTab(String? tabId) {
    for (final (id, path, _) in kShellTabs) {
      if (id == tabId) {
        _router.go(path);
        return;
      }
    }
  }
}
