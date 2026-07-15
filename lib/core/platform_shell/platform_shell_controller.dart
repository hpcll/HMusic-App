import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/player/view_models/player_view_model.dart';
import '../../features/player/views/player_page.dart';
import '../../features/queue/views/queue_page.dart';
import '../../features/search/views/search_page.dart';
import 'platform_shell_bridge.dart';

// Dart 侧 chrome 桥接与 intent 派发的单一出口：原生层只回传语义 intent，
// 这里翻译成 Router/PlayerViewModel 调用。Swift 不持有业务状态，intent 必须回到这里。
// P0 只冻结可验证的一半：intent 派发 + navigation 下发；
// SwiftUI 玻璃渲染与真机折射留作设备门禁（见 docs/06 §3、docs/09 §7）。
class PlatformShellController extends ChangeNotifier {
  PlatformShellController({
    required PlatformShellBridge bridge,
    required GoRouter router,
    required PlayerViewModel playerViewModel,
  }) : _bridge = bridge,
       _router = router,
       _playerViewModel = playerViewModel {
    _intentSubscription = _bridge.intents.listen(_handleIntent);
  }

  final PlatformShellBridge _bridge;
  final GoRouter _router;
  final PlayerViewModel _playerViewModel;

  late final StreamSubscription<ShellIntentType> _intentSubscription;
  String _selectedTab = 'search';

  String get selectedTab => _selectedTab;

  @override
  void dispose() {
    unawaited(_intentSubscription.cancel());
    super.dispose();
  }

  // 在路由变化或主动同步时调用：把当前 tab/标题/可回退下发到原生 chrome。
  // canGoBack 取 router 的非根历史；mini player 隐藏由路由决定，不在通道里单独传。
  Future<void> syncNavigation({
    required String selectedTab,
    required String title,
    bool canGoBack = false,
  }) async {
    _selectedTab = selectedTab;
    await _bridge.updateNavigation(
      selectedTab: selectedTab,
      title: title,
      canGoBack: canGoBack,
    );
  }

  // 把无障碍/主题偏好下发，供原生层切换材质或降级（降低透明度/减少动态效果）。
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

  // 语义 intent → 路由/播放命令。seek 与 dismiss 在 P0 忽略并保持静默，
  // 不抛异常以免原生壳崩溃拖垮 Flutter 帧树。
  @visibleForTesting
  void handleIntent(ShellIntentType intent) => _handleIntent(intent);

  void _handleIntent(ShellIntentType intent) {
    switch (intent) {
      case ShellIntentType.selectTab:
        _selectTab(_selectedTab);
      case ShellIntentType.openNowPlaying:
        unawaited(_router.push(PlayerPage.path));
      case ShellIntentType.playPause:
        unawaited(_playerViewModel.play());
      case ShellIntentType.previous:
        unawaited(_playerViewModel.skipToPrevious());
      case ShellIntentType.next:
        unawaited(_playerViewModel.skipToNext());
      case ShellIntentType.seek:
      case ShellIntentType.dismiss:
        break;
    }
  }

  void _selectTab(String tab) {
    switch (tab) {
      case 'search':
        _router.go(SearchPage.path);
      case 'queue':
        _router.go(QueuePage.path);
      case 'nowPlaying':
        unawaited(_router.push(PlayerPage.path));
    }
  }
}
