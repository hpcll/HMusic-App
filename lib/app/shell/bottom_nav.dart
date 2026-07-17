import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform_shell/widgets/adaptive_glass_surface.dart';
import '../../shared/layout/shell_metrics.dart';
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

// 窄屏 dock 5 tab 精选（播放/队列走 mini player push 全屏页，移动专属交互）。
const List<NavDestinationSpec> kNavDestinations = <NavDestinationSpec>[
  NavDestinationSpec(Icons.leaderboard_rounded, '榜单', 4),
  NavDestinationSpec(Icons.search_rounded, '搜索', 1),
  NavDestinationSpec(Icons.library_music_rounded, '歌单', 3),
  NavDestinationSpec(Icons.insights_rounded, '统计', 5),
  NavDestinationSpec(Icons.settings_rounded, '设置', 6),
];

// 窄屏悬浮玻璃 dock，形态对齐 iOS 26+ 原生壳（GlassShellOverlay）：胶囊压进
// 安全区、悬在 home indicator 上方；展开 = 5 tab 等分胶囊条，滚动收缩 =
// 单枚当前 tab pill 居中（点 pill 只展开，不切 tab）。图标 22px、标签 11px、
// active 墨色/其余 muted，与 Swift DockItem 同纪律。
// 材质差异是唯一的平台分叉：iOS 26+ 由原生壳接管（本组件不渲染），
// Android/iOS<26 在此用 AdaptiveGlassSurface 毛玻璃，off 档退不透明面板。
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    required this.shell,
    this.minimized = false,
    this.onExpand,
    super.key,
  });

  final StatefulNavigationShell shell;

  // 滚动收缩态，由外壳依滚动方向驱动（对齐 GlassShellState.minimized）。
  final bool minimized;

  // 收缩态点 pill 的展开回调（对齐原生 expandDock intent）。
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(kChromeDockHeight / 2));
    final active = kNavDestinations.firstWhere(
      (spec) => spec.branch == shell.currentIndex,
      orElse: () => kNavDestinations.first,
    );
    return AdaptiveGlassSurface(
      quality: resolveGlassQuality(context),
      padding: EdgeInsets.zero,
      borderRadius: radius,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : kChromeMorphDuration,
          curve: Curves.easeOut,
          child: SizedBox(
            height: kChromeDockHeight,
            child: minimized
                ? _NavItem(
                    spec: active,
                    active: true,
                    compact: true,
                    onTap: () => onExpand?.call(),
                  )
                : Row(
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
    this.compact = false,
  });

  final NavDestinationSpec spec;
  final bool active;
  final VoidCallback onTap;

  // 收缩 pill 形态：不等分拉伸，按内容宽 + 左右 26 内边距（对齐 Swift DockItem）。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = active ? palette.textStrong : palette.muted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 26 : 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(spec.icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(spec.label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
