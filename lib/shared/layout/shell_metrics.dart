import 'dart:math' as math;

// 外壳布局常量：侧栏、悬浮 mini player 与移动悬浮玻璃 chrome 的占位尺寸。
// 放 shared 是为了让全局 toast 这类覆盖层能避开外壳 chrome，而不用从 shared
// 反向依赖 app/features。改动时同步 docs/03（--sidebar-w / mini 包络）。

// 桌面固定侧栏宽，对齐 web --sidebar-w:232px。
const double kSidebarWidth = 232;

// 悬浮 mini 的包络高度：外边距 12 + 行内容 ~58 + 进度线 2。
const double kMiniPlayerDesktopInset = 76;

// 窄屏悬浮玻璃 chrome（dock + mini 胶囊）：数值与 iOS 原生壳 GlassShellMetrics
// 严格一致——Android/iOS<26 的 Flutter 回退壳要与 iOS 26+ 液态玻璃壳同形态，
// 只是材质换成 BackdropFilter 毛玻璃。改动时两侧必须同步。
const double kChromeDockHeight = 66;
// mini 比 dock 矮一档（50 vs 66）：dock 是导航主锚点，mini 是次级播放状态条。
const double kChromeMiniHeight = 50;
const double kChromeGap = 8;
const double kChromeHorizontalPadding = 16;

// 内容与 chrome 顶缘之间的呼吸距，计入内容滚动区的底部让位。
const double kChromeContentClearance = 8;

// chrome 收缩/展开的容器尺寸动效，对齐 docs/05「mini player 显隐 220ms easeOut」。
const Duration kChromeMorphDuration = Duration(milliseconds: 220);

// chrome 底缘到屏幕物理底边的距离：压进安全区、悬在 home indicator/手势条
// 上方（对齐 GlassShellMetrics.bottomOffset），无安全区设备退到 10。
double chromeBottomOffset(double safeArea) => math.max(10, safeArea - 10);
