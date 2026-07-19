import 'dart:math' as math;

import 'package:flutter/animation.dart';

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

// 收缩圆钮的固定宽度：图标 22 + 左右内边距 26×2，写死是为了让外壳能按
// 同一目标宽做 dock「向右缩短」与 mini 让位的几何插值。
const double kChromeCompactDockWidth = 74;

// dock↔圆钮 收纳形变时长/曲线：几何插值（宽/高/圆角/交叉淡化）比纯尺寸
// 动画信息量大，放慢到 320ms 才读得清「缩到右侧」的方向感；mini 胶囊自身
// 的显隐仍走 docs/05 的 220ms easeOut。两处数值改动需同步 docs/03 §4。
const Duration kChromeMorphDuration = Duration(milliseconds: 320);
const Curve kChromeMorphCurve = Curves.easeOutCubic;

// dock 选中药丸从 A tab 滑到 B tab 的时长（对齐 iOS 26+ 系统 tab bar 手感）。
const Duration kDockPillDuration = Duration(milliseconds: 260);

// chrome 底缘到屏幕物理底边的距离：压进安全区、悬在 home indicator/手势条
// 上方（对齐 GlassShellMetrics.bottomOffset），无安全区设备退到 10。
double chromeBottomOffset(double safeArea) => math.max(10, safeArea - 10);
