import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/painting.dart' show TextScaler;

// 外壳布局常量：侧栏、悬浮 mini player 与移动悬浮玻璃 chrome 的占位尺寸。
// 放 shared 是为了让全局 toast 这类覆盖层能避开外壳 chrome，而不用从 shared
// 反向依赖 app/features。改动时同步 docs/03（--sidebar-w / mini 包络）。

enum ShellNavigationMode { bottom, rail, sidebar }

const double kShellBottomNavigationBreakpoint = 700;
const double kShellExpandedNavigationBreakpoint = 1024;
const double kNavigationRailWidth = 80;

// 路由使用视口宽度决定导航方式；页面自身分栏应读取 LayoutBuilder 的内容宽度。
ShellNavigationMode shellNavigationModeForWidth(double viewportWidth) {
  if (usesBottomNavigation(viewportWidth)) return ShellNavigationMode.bottom;
  return viewportWidth < kShellExpandedNavigationBreakpoint
      ? ShellNavigationMode.rail
      : ShellNavigationMode.sidebar;
}

bool usesBottomNavigation(double viewportWidth) =>
    viewportWidth < kShellBottomNavigationBreakpoint;

double shellNavigationWidth(double viewportWidth) =>
    switch (shellNavigationModeForWidth(viewportWidth)) {
      ShellNavigationMode.bottom => 0,
      ShellNavigationMode.rail => kNavigationRailWidth,
      ShellNavigationMode.sidebar => kSidebarWidth,
    };

double shellWindowTopInset(TargetPlatform platform) =>
    platform == TargetPlatform.macOS ? 28 : 0;

// 完整侧栏保持既有宽度，中屏采用更窄的 rail。
const double kSidebarWidth = 232;

// 仅供已存档 HMusicToast 保持旧定位测试；产品桌面条使用 desktopPlaybackBarHeight。
const double kMiniPlayerDesktopInset = 76;

// 窄屏悬浮玻璃 chrome（dock + mini 胶囊）：数值与 iOS 原生壳 GlassShellMetrics
// 同形态——Android/iOS<26 的 Flutter 回退壳要与 iOS 26+ 液态玻璃壳同布局语言，
// 只是材质换成 BackdropFilter 毛玻璃。
// 2026-09-05 用户要求 dock 略薄：66→62，选中胶囊（52）尺寸不动（上下留白
// 7→5 吸收），dock 不得矮于胶囊。iOS 26+ 原生 dock 由系统自绘（66），本常量
// 只作用于 Flutter 回退壳，两侧允许这一处不一致。
const double kChromeDockHeight = 62;
// 保持原来的纤细两行 mini；大字时壳与内容共用增高后的包络。
const double kChromeMiniHeight = 50;
const double kChromeMiniTitleFontSize = 14;
const double kChromeMiniDetailFontSize = 12;
const double kChromeMiniLineHeight = 1.25;
const double kChromeGap = 8;
const double kChromeHorizontalPadding = 16;

// 内容与 chrome 顶缘之间的呼吸距，计入内容滚动区的底部让位。
const double kChromeContentClearance = 8;

// 收起态两侧圆钮与 mini 等高，中间只保留封面、曲名和播放键。
const double kChromeMinimumCompactMiniWidth = 160;

double mobileMiniPlayerHeight(TextScaler textScaler) => math.max(
  kChromeMiniHeight,
  (14 +
          (textScaler.scale(kChromeMiniTitleFontSize) +
                  textScaler.scale(kChromeMiniDetailFontSize)) *
              kChromeMiniLineHeight)
      .ceilToDouble(),
);

// 图标 28、图文间距 3、上下留白 10；标签显式按 1.25 行高绘制。
double mobileDockHeight(TextScaler textScaler) => math.max(
  kChromeDockHeight,
  (41 + textScaler.scale(11) * 1.25).ceilToDouble(),
);

bool canMinimizeBottomChrome({
  required double viewportWidth,
  required TextScaler textScaler,
}) =>
    textScaler.scale(kChromeMiniDetailFontSize) <=
        kChromeMiniDetailFontSize * 1.2 &&
    viewportWidth -
            2 * kChromeHorizontalPadding -
            2 * (mobileMiniPlayerHeight(textScaler) + kChromeGap) >=
        kChromeMinimumCompactMiniWidth;

// dock↔圆钮 收纳形变时长/曲线：几何插值（宽/高/圆角/交叉淡化）比纯尺寸
// 动画信息量大，放慢到 320ms 才读得清「导航收左、mini 居中下落」的方向感；mini 胶囊自身
// 的显隐仍走 docs/05 的 220ms easeOut。两处数值改动需同步 docs/03 §4。
const Duration kChromeMorphDuration = Duration(milliseconds: 320);
const Curve kChromeMorphCurve = Curves.easeOutCubic;

// dock 选中药丸从 A tab 滑到 B tab 的时长（对齐 iOS 26+ 系统 tab bar 手感）。
const Duration kDockPillDuration = Duration(milliseconds: 260);

// chrome 底缘到屏幕物理底边的距离：压进安全区、悬在 home indicator/手势条上方。
//
// 两个平台不是同一个算法，因为「安全区」在两边的含义不同：
// - iOS 的 34pt 里，home indicator 自身只占底部约 13pt，减 10 正好留出呼吸；
//   这一支与原生玻璃壳 GlassShellMetrics.bottomOffset 同式，两侧必须一致。
// - Android 手势条的安全区（常见 16dp）几乎就等于那颗胶囊自身的高度，再往里
//   减就直接压在它身上（用户反馈「dock 栏和手势条重叠了」）；三键导航的 48dp
//   是一条实体栏，更不能减。所以让开整条安全区再留 8 的呼吸。
double chromeBottomOffset(double safeArea, {required TargetPlatform platform}) {
  if (platform == TargetPlatform.iOS) return math.max(10, safeArea - 10);
  return math.max(12, safeArea + 8);
}
