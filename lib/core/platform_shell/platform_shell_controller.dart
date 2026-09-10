import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/player/view_models/player_view_model.dart';
import '../../features/player/views/player_page.dart';
import '../../features/search/views/search_page.dart';
import 'platform_shell_bridge.dart';
import 'shell_navigation.dart';

export 'shell_navigation.dart' show kShellTabs;

// Flutter 仍是路由与播放状态源；原生只接收展示数据并回传语义 intent。
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
  StreamSubscription<PlaybackState>? _playbackSubscription;

  bool _disposed = false;
  List<String> _capabilities = const <String>[];
  double _nativeBottomInset = 0;
  MediaItem? _track;
  bool _playing = false;
  String _outputLabel = '未选择设备';
  bool _scrollMinimized = false;
  var _viewport = (
    useBottomChrome: false,
    miniPlayerHeight: 50.0,
    miniTitleFontSize: 14.0,
    miniDetailFontSize: 12.0,
    allowMinimize: false,
  );
  var _configuration = (
    darkMode: PlatformDispatcher.instance.platformBrightness == Brightness.dark,
    reduceMotion: false,
    reduceTransparency: false,
  );
  (String?, String?, String?, String?, bool, String)? _sentNowPlaying;
  (String, String, bool)? _sentNavigation;
  (bool, bool, double, double, double, bool)? _sentLayout;

  // viewport 尚未送达时先使用 Flutter 壳，避免宽 iPad 在 ready 首帧出现双份导航。
  bool get nativeChromeActive =>
      _viewport.useBottomChrome &&
      _capabilities.contains('bottomBar') &&
      _capabilities.contains('miniPlayer');

  double get nativeBottomInset =>
      _viewport.useBottomChrome ? _nativeBottomInset : 0;

  @override
  void dispose() {
    _disposed = true;
    _router.routerDelegate.removeListener(_onRouteChanged);
    unawaited(_intentSubscription.cancel());
    unawaited(_readySubscription.cancel());
    unawaited(_layoutSubscription.cancel());
    unawaited(_playbackSubscription?.cancel());
    super.dispose();
  }

  void attachAudioHandler(BaseAudioHandler handler) {
    if (_disposed) return;
    unawaited(_playbackSubscription?.cancel());
    _playbackSubscription = handler.playbackState.listen((state) {
      if (state.playing == _playing) return;
      _playing = state.playing;
      _pushNowPlaying();
    });
  }

  // 展示曲目与输出同源于 Server；冷恢复时本机尚未装载 MediaItem 也能显示。
  void updateMetadata({
    required MediaItem? track,
    required String outputLabel,
  }) {
    if (_disposed) return;
    _track = track;
    _outputLabel = outputLabel;
    _pushNowPlaying();
  }

  void updateViewport({
    required bool useBottomChrome,
    required double miniPlayerHeight,
    required double miniTitleFontSize,
    required double miniDetailFontSize,
    required bool allowMinimize,
  }) {
    if (_disposed) return;
    final viewport = (
      useBottomChrome: useBottomChrome,
      miniPlayerHeight: miniPlayerHeight,
      miniTitleFontSize: miniTitleFontSize,
      miniDetailFontSize: miniDetailFontSize,
      allowMinimize: allowMinimize,
    );
    if (viewport == _viewport) return;
    _viewport = viewport;
    if ((!useBottomChrome || !allowMinimize) && _scrollMinimized) {
      _scrollMinimized = false;
      unawaited(_bridge.updateScroll(minimized: false));
    }
    _onRouteChanged();
    notifyListeners();
  }

  Future<void> configure({
    required bool darkMode,
    required bool reduceMotion,
    required bool reduceTransparency,
  }) {
    _configuration = (
      darkMode: darkMode,
      reduceMotion: reduceMotion,
      reduceTransparency: reduceTransparency,
    );
    return _pushConfiguration();
  }

  Future<void> _pushConfiguration() => _bridge.configure(
    darkMode: _configuration.darkMode,
    reduceMotion: _configuration.reduceMotion,
    reduceTransparency: _configuration.reduceTransparency,
  );

  @visibleForTesting
  void handleIntent(ShellIntent intent) => _handleIntent(intent);

  void _onReady(ShellReady ready) {
    _capabilities = ready.capabilities;
    _sentNavigation = null;
    _sentLayout = null;
    _sentNowPlaying = null;
    _onRouteChanged();
    _pushNowPlaying();
    unawaited(_pushConfiguration());
    notifyListeners();
  }

  void _onLayout(ShellLayout layout) {
    if (layout.bottomInset == _nativeBottomInset) return;
    _nativeBottomInset = layout.bottomInset;
    notifyListeners();
  }

  void reportScroll({required bool minimized}) {
    if (!nativeChromeActive ||
        (minimized && !_viewport.allowMinimize) ||
        minimized == _scrollMinimized) {
      return;
    }
    _scrollMinimized = minimized;
    unawaited(_bridge.updateScroll(minimized: minimized));
  }

  String get _currentPath {
    final matches = _router.routerDelegate.currentConfiguration.matches;
    return matches.isEmpty ? '' : matches.last.matchedLocation;
  }

  void _openOverlay(String path) {
    if (_currentPath != path) unawaited(_router.push(path));
  }

  void _onRouteChanged() {
    final page = shellRoutePresentationForPath(_currentPath);
    final navigation = (page?.tabId ?? '', page?.title ?? '', _router.canPop());
    if (navigation != _sentNavigation) {
      final tabChanged = navigation.$1 != _sentNavigation?.$1;
      _sentNavigation = navigation;
      unawaited(
        _bridge.updateNavigation(
          selectedTab: navigation.$1,
          title: navigation.$2,
          canGoBack: navigation.$3,
        ),
      );
      if (tabChanged && _scrollMinimized) {
        _scrollMinimized = false;
        unawaited(_bridge.updateScroll(minimized: false));
      }
    }
    final visible = _viewport.useBottomChrome && page != null;
    final layout = (
      visible,
      visible && page.showMini,
      _viewport.miniPlayerHeight,
      _viewport.miniTitleFontSize,
      _viewport.miniDetailFontSize,
      _viewport.allowMinimize,
    );
    if (layout == _sentLayout) return;
    _sentLayout = layout;
    unawaited(
      _bridge.updateLayout(
        showTabBar: layout.$1,
        showMiniPlayer: layout.$2,
        miniPlayerHeight: layout.$3,
        miniTitleFontSize: layout.$4,
        miniDetailFontSize: layout.$5,
        allowMinimize: layout.$6,
      ),
    );
  }

  void _pushNowPlaying() {
    final snapshot = (
      _track?.id,
      _track?.title,
      _track?.artist,
      _track?.artUri?.toString(),
      _playing,
      _outputLabel,
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
        outputLabel: snapshot.$6,
      ),
    );
  }

  void _handleIntent(ShellIntent intent) {
    switch (intent.type) {
      case ShellIntentType.selectTab:
        for (final (id, path, _) in kShellTabs) {
          if (id == intent.value) {
            _router.go(path);
            break;
          }
        }
      case ShellIntentType.openNowPlaying:
        _openOverlay(PlayerPage.path);
      case ShellIntentType.openSearch:
        _openOverlay(SearchPage.path);
      case ShellIntentType.openOutputPicker:
        _openOverlay(kOutputPickerPath);
      case ShellIntentType.playPause:
        unawaited(
          _playing ? _playerViewModel.pause() : _playerViewModel.play(),
        );
      case ShellIntentType.previous:
        unawaited(_playerViewModel.skipToPrevious());
      case ShellIntentType.next:
        unawaited(_playerViewModel.skipToNext());
      case ShellIntentType.expandDock:
        _scrollMinimized = false;
      case ShellIntentType.seek:
      case ShellIntentType.dismiss:
        break;
    }
  }
}
