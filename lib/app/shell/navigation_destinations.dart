import 'package:flutter/material.dart';

// branch 顺序是既有路由合同，展示入口可以分组，不重排路由本身。
class NavDestinationSpec {
  const NavDestinationSpec(this.icon, this.label, this.branch);

  final IconData icon;
  final String label;
  final int branch;
}

const int kHomeBranch = 4;
const int kLibraryBranch = 3;
const int kStatsBranch = 5;
const int kSettingsBranch = 6;

const List<NavDestinationSpec> kNavDestinations = <NavDestinationSpec>[
  NavDestinationSpec(Icons.local_fire_department_rounded, '榜单', kHomeBranch),
  NavDestinationSpec(Icons.library_music_rounded, '歌单', kLibraryBranch),
  NavDestinationSpec(Icons.insights_rounded, '统计', kStatsBranch),
  NavDestinationSpec(Icons.settings_rounded, '设置', kSettingsBranch),
];

const List<(String, List<NavDestinationSpec>)> kSidebarGroups = [
  (
    '浏览',
    [
      NavDestinationSpec(Icons.search_rounded, '搜索', 1),
      NavDestinationSpec(
        Icons.local_fire_department_rounded,
        '榜单',
        kHomeBranch,
      ),
    ],
  ),
  (
    '音乐库',
    [
      NavDestinationSpec(Icons.library_music_rounded, '曲库', kLibraryBranch),
      NavDestinationSpec(Icons.insights_rounded, '听歌统计', kStatsBranch),
    ],
  ),
  (
    '播放',
    [
      NavDestinationSpec(Icons.play_circle_outline_rounded, '正在播放', 0),
      NavDestinationSpec(Icons.queue_music_rounded, '队列', 2),
    ],
  ),
  ('设置', [NavDestinationSpec(Icons.settings_rounded, '设置', kSettingsBranch)]),
];

// 宽窗分支缩到手机宽度时仍保留页面；底栏显示它所属的主要入口。
int mobileParentBranch(int branch) => switch (branch) {
  0 || 2 => kLibraryBranch,
  1 => kHomeBranch,
  _ => branch,
};
