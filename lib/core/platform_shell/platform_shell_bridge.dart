enum ShellIntentType {
  selectTab,
  openNowPlaying,
  playPause,
  previous,
  next,
  seek,
  dismiss,
  // 原生收缩态 pill 被点开：Swift 本地立即展开，同时回传此 intent
  // 让 Dart 复位滚动去重状态，否则下一次下滑上报会被去重拦截。
  expandDock,
}

// 原生回传的语义 intent；selectTab 用 value 携带目标 tab id（charts/search/...）。
class ShellIntent {
  const ShellIntent(this.type, [this.value]);

  final ShellIntentType type;
  final String? value;
}

class ShellLayout {
  const ShellLayout({required this.topInset, required this.bottomInset});

  final double topInset;
  final double bottomInset;
}

// 原生壳就绪声明：capabilities 列出可渲染的 chrome 元素（bottomBar/miniPlayer），
// 为空表示原生不接管，Flutter 回退壳继续负责全部 chrome。
class ShellReady {
  const ShellReady({required this.capabilities});

  final List<String> capabilities;
}

abstract interface class PlatformShellBridge {
  Stream<ShellReady> get readyEvents;

  Stream<ShellLayout> get layoutChanges;

  Stream<ShellIntent> get intents;

  Future<void> configure({
    required bool darkMode,
    required bool reduceMotion,
    required bool reduceTransparency,
  });

  Future<void> updateNavigation({
    required String selectedTab,
    required String title,
    required bool canGoBack,
  });

  // trackId 为 null 表示当前无曲目，原生隐藏 mini player 内容。
  Future<void> updateNowPlaying({
    required String? trackId,
    required String? title,
    required String? artist,
    required String? artworkUrl,
    required bool playing,
  });

  // showTabBar 随路由：5 个 tab 页显示 dock，全屏页（player/lyrics/连接/登录）整体隐藏。
  Future<void> updateLayout({
    required bool showTabBar,
    required bool showMiniPlayer,
  });

  // 内容垂直滚动 → 原生 chrome 收缩/展开：向下滚收缩、滚回顶部展开
  //（对齐 Apple Music 滚动收纳行为）。
  // 原生 ScrollView 看不见 Flutter 滚动，必须由 Dart 上报。
  Future<void> updateScroll({required bool minimized});
}
