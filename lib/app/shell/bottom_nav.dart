import 'dart:ui' show lerpDouble;

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

// 主页分支 = 榜单（登录后落点、dock 首项）：系统返回的壳层兜底目标——
// 非主页 tab 一级页按返回先回这里，主页再返回才交还系统退出 App。
const int kHomeBranch = 4;

// 窄屏 dock 4 tab 精选（播放/队列走 mini player push 全屏页；搜索并入
// 榜单页头胶囊 push 全屏页——搜索页内容太薄，不值一个常驻 tab）。
const List<NavDestinationSpec> kNavDestinations = <NavDestinationSpec>[
  NavDestinationSpec(Icons.leaderboard_rounded, '榜单', kHomeBranch),
  NavDestinationSpec(Icons.library_music_rounded, '歌单', 3),
  NavDestinationSpec(Icons.insights_rounded, '统计', 5),
  NavDestinationSpec(Icons.settings_rounded, '设置', 6),
];

// 窄屏悬浮玻璃 dock，形态对齐 iOS 26+ 原生壳（GlassShellOverlay）：胶囊压进
// 安全区、悬在 home indicator 上方。展开 = 5 tab 等分胶囊条，选中态是会在
// tab 间滑动的灰药丸（对齐 Apple Music tab bar，与 Swift 侧
// matchedGeometryEffect 同纪律）；滚动收缩 = 胶囊「向右缩短」成当前 tab 的
// 图标圆钮——右缘钉住、宽高圆角连续插值、整条 tab 层与圆钮交叉淡化，端点
// 只挂单层（点圆钮只展开，不切 tab）。图标 22px、标签 11px。
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

  // 收缩态点圆钮的展开回调（对齐原生 expandDock intent）。
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;
        // 与外壳的收纳插值同目标/同时长/同曲线，逐帧几何自然对得上。
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: minimized ? 1 : 0),
          duration: disableAnimations ? Duration.zero : kChromeMorphDuration,
          curve: kChromeMorphCurve,
          builder: (context, t, _) => _buildDock(context, t, fullWidth),
        );
      },
    );
  }

  // t=0 展开条 / t=1 收缩圆钮；中途宽高圆角插值 + 两层交叉淡化。
  Widget _buildDock(BuildContext context, double t, double fullWidth) {
    final height = lerpDouble(kChromeDockHeight, kChromeMiniHeight, t)!;
    final width = lerpDouble(fullWidth, kChromeCompactDockWidth, t)!;
    final radius = BorderRadius.circular(height / 2);
    final active = kNavDestinations.firstWhere(
      (spec) => spec.branch == shell.currentIndex,
      orElse: () => kNavDestinations.first,
    );
    // 端点只挂对应单层：语义树干净（收缩态查不到 5 tab），命中判定无歧义。
    final showRow = t < 1;
    final showCompact = t > 0;
    final rowOpacity = (1 - t / 0.55).clamp(0.0, 1.0);
    final compactOpacity = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
    return AdaptiveGlassSurface(
      quality: resolveGlassQuality(context),
      padding: EdgeInsets.zero,
      borderRadius: radius,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: <Widget>[
              // 整条 tab 层右缘钉在胶囊右缘、保持全宽不压缩：胶囊缩短时内容
              // 原地不动、从左侧被裁掉，读作「dock 向右收拢」而非挤压变形。
              if (showRow)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: fullWidth,
                  child: IgnorePointer(
                    ignoring: t > 0.5,
                    child: Opacity(opacity: rowOpacity, child: _row(context)),
                  ),
                ),
              if (showCompact)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: kChromeCompactDockWidth,
                  child: IgnorePointer(
                    ignoring: t <= 0.5,
                    child: Opacity(
                      opacity: compactOpacity,
                      child: _NavItem(
                        spec: active,
                        active: true,
                        compact: true,
                        onTap: () => onExpand?.call(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 展开条：底层灰药丸滑到选中 tab（AnimatedAlign 从 A 滑到 B），上层 5 等分项。
  Widget _row(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final activeIndex = kNavDestinations.indexWhere(
      (spec) => spec.branch == shell.currentIndex,
    );
    return Stack(
      children: <Widget>[
        // 当前分支不在 dock 5 tab 内（如全屏播放页分支）时无选中项，不画药丸。
        if (activeIndex >= 0)
          AnimatedAlign(
            alignment: Alignment(
              -1 + activeIndex * 2 / (kNavDestinations.length - 1),
              0,
            ),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : kDockPillDuration,
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 1 / kNavDestinations.length,
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    // 灰药丸只做「所在位置」提示，浓度压低不与青绿纪律抢戏。
                    color: palette.textStrong.withValues(
                      alpha: dark ? 0.12 : 0.07,
                    ),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
          ),
        Row(
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
      ],
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

  // 收缩圆钮形态：只留图标（标签语义交给 Semantics），不等分拉伸，
  // 按内容宽 + 左右 26 内边距（对齐 Swift DockItem compact）。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = active ? palette.textStrong : palette.muted;
    final content = compact
        ? Center(widthFactor: 1, child: Icon(spec.icon, size: 22, color: color))
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(spec.icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(spec.label, style: TextStyle(fontSize: 11, color: color)),
            ],
          );
    // 点按反馈由滑动药丸承担，压掉矩形水波纹（「正方形」高亮的来源）。
    final item = InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 26 : 0),
        child: content,
      ),
    );
    if (!compact) return item;
    return Semantics(label: spec.label, button: true, child: item);
  }
}
