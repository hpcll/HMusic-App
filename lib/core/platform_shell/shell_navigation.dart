// 移动 dock 恢复原四项；保留既有路由、native id 及桌面分支。
const List<(String id, String path, String title)> kShellTabs = [
  ('charts', '/charts', '榜单'),
  ('playlists', '/playlists', '歌单'),
  ('stats', '/stats', '统计'),
  ('settings', '/settings', '设置'),
];

const String kOutputPickerPath = '/outputs';

class ShellRoutePresentation {
  const ShellRoutePresentation(this.tabId, this.title, {this.showMini = true});

  final String tabId;
  final String title;
  final bool showMini;
}

// 桌面分支缩到手机时页面保留，底栏显示父入口；独立全屏路由没有底部 chrome。
ShellRoutePresentation? shellRoutePresentationForPath(String path) =>
    switch (path) {
      '/charts' => const ShellRoutePresentation('charts', '榜单'),
      '/search-tab' => const ShellRoutePresentation('charts', '搜索'),
      '/playlists' => const ShellRoutePresentation('playlists', '歌单'),
      '/stats' => const ShellRoutePresentation('stats', '统计'),
      '/now' => const ShellRoutePresentation(
        'playlists',
        '正在播放',
        showMini: false,
      ),
      '/queue-tab' => const ShellRoutePresentation('playlists', '播放队列'),
      '/settings' => const ShellRoutePresentation('settings', '设置'),
      _ => null,
    };
