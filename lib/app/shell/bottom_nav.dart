import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform_shell/widgets/adaptive_glass_surface.dart';
import '../theme/hmusic_palette.dart';

// 导航项定义：icon + label + 对应 shell branch index（7 分支顺序对齐 web 侧栏）。
class NavDestinationSpec {
  const NavDestinationSpec(this.icon, this.label, this.branch);
  final IconData icon;
  final String label;

  // StatefulShellRoute 分支下标（app_router 分支顺序）。
  final int branch;
}

// 桌面侧栏 7 项，对齐 web .sidebar：正在播放/搜索/队列/歌单/榜单/统计/设置。
const List<NavDestinationSpec> kSidebarDestinations = <NavDestinationSpec>[
  NavDestinationSpec(Icons.play_circle_outline_rounded, '正在播放', 0),
  NavDestinationSpec(Icons.search_rounded, '搜索', 1),
  NavDestinationSpec(Icons.queue_music_rounded, '队列', 2),
  NavDestinationSpec(Icons.library_music_rounded, '歌单', 3),
  NavDestinationSpec(Icons.leaderboard_rounded, '榜单', 4),
  NavDestinationSpec(Icons.insights_rounded, '统计', 5),
  NavDestinationSpec(Icons.settings_rounded, '设置', 6),
];

// 窄屏底栏 5 tab 精选（播放/队列走 mini player push 全屏页，移动专属交互）。
const List<NavDestinationSpec> kNavDestinations = <NavDestinationSpec>[
  NavDestinationSpec(Icons.leaderboard_rounded, '榜单', 4),
  NavDestinationSpec(Icons.search_rounded, '搜索', 1),
  NavDestinationSpec(Icons.library_music_rounded, '歌单', 3),
  NavDestinationSpec(Icons.insights_rounded, '统计', 5),
  NavDestinationSpec(Icons.settings_rounded, '设置', 6),
];

// 窄屏底部导航，对齐 web .bottom-nav / .nav-item：
// 流内底栏（非 fixed）+ 顶部细边 + 安全区内边距；active 字→text-strong，图标 21px、标签 10.5px。
// 全宽玻璃条形态（外壳 extendBody，内容从底栏下滚过）。
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AdaptiveGlassSurface(
      quality: resolveGlassQuality(context),
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.zero,
      border: Border(top: BorderSide(color: palette.line)),
      shadow: false,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: <Widget>[
              for (final spec in kNavDestinations)
                Expanded(
                  child: _NavItem(
                    spec: spec,
                    active: shell.currentIndex == spec.branch,
                    onTap: () => _go(spec.branch),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // goBranch: 再次点当前 tab 回到该分支初始位置（对齐常见底栏交互）。
  void _go(int index) {
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.active,
    required this.onTap,
  });

  final NavDestinationSpec spec;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = active ? palette.textStrong : palette.muted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(spec.icon, size: 21, color: color),
            const SizedBox(height: 3),
            Text(spec.label, style: TextStyle(fontSize: 10.5, color: color)),
          ],
        ),
      ),
    );
  }
}
