enum ShellIntentType {
  selectTab,
  openNowPlaying,
  playPause,
  previous,
  next,
  seek,
  dismiss,
}

class ShellLayout {
  const ShellLayout({required this.topInset, required this.bottomInset});

  final double topInset;
  final double bottomInset;
}

abstract interface class PlatformShellBridge {
  Stream<ShellLayout> get layoutChanges;

  Stream<ShellIntentType> get intents;

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
}
