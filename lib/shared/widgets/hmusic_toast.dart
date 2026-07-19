import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/hmusic_palette.dart';
import '../../core/platform_shell/widgets/adaptive_glass_surface.dart';
import '../layout/shell_metrics.dart';
import '../models/hmusic_notice.dart';

OverlayEntry? _entry;
Timer? _timer;

// Toast 提示，对齐 docs/03 规格并升级为液态玻璃风格：水平居中、内容自适应宽
//（max 90%）、**胶囊形态**（高度 / 2 圆角）+ **毛玻璃材质**（对齐 mini/dock
// 的液态语言）、3px 语义左边框内嵌于玻璃之下、无动画纯出现/消失、3.2s 自动
// 消失，新 toast 顶替旧 toast。全站轻量结果提示统一走这里，别再用 SnackBar——
// floating SnackBar 在桌面宽窗会拉成整行黑条，且无法关掉出入场动画。
// 直插 root Overlay + IgnorePointer：不参与页面布局，也不挡底部区域的点击。
// 底距在 web bottom:28/92 基础上避让本壳的底部 chrome（见 _HMusicToast）。
void showHMusicToast(BuildContext context, HMusicNotice notice) {
  final overlay = Overlay.of(context, rootOverlay: true);
  hideHMusicToast();
  final entry = OverlayEntry(
    builder: (context) => _HMusicToast(notice: notice),
  );
  _entry = entry;
  overlay.insert(entry);
  _timer = Timer(const Duration(milliseconds: 3200), hideHMusicToast);
}

void hideHMusicToast() {
  _timer?.cancel();
  _timer = null;
  _entry?.remove();
  _entry?.dispose();
  _entry = null;
}

class _HMusicToast extends StatelessWidget {
  const _HMusicToast({required this.notice});

  final HMusicNotice notice;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final size = MediaQuery.sizeOf(context);
    // 断点 860 与 app_shell 一致。web 的 28/92 是按「底边无 chrome/有底栏」
    // 定的；本壳桌面有悬浮 mini（包络 76），toast 抬到其上再留 12 空隙，且
    // mini 隐藏时保持同一高度，不随播放状态跳动。窄屏按悬浮玻璃 chrome 的
    // 完整包络让位（dock + gap + mini 胶囊 + 呼吸距，原生壳与回退壳同数值），
    // 同样不随播放状态跳动。
    final desktop = size.width >= 860;
    final bottom = desktop
        ? kMiniPlayerDesktopInset + 12
        : chromeBottomOffset(MediaQuery.paddingOf(context).bottom) +
              kChromeDockHeight +
              kChromeGap +
              kChromeMiniHeight +
              kChromeContentClearance;
    // 桌面居中于侧栏右侧的内容区，而不是整窗——和 mini/页面同一根轴线。
    final contentWidth = desktop ? size.width - kSidebarWidth : size.width;
    final edge = switch (notice.kind) {
      HMusicNoticeKind.info => palette.mutedStrong,
      HMusicNoticeKind.success => palette.accent,
      HMusicNoticeKind.error => palette.danger,
    };
    return Positioned(
      left: desktop ? kSidebarWidth : 0,
      right: 0,
      bottom: bottom,
      child: IgnorePointer(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth * 0.9),
            child: _ToastCapsule(palette: palette, edge: edge, notice: notice),
          ),
        ),
      ),
    );
  }
}

// 胶囊 toast：毛玻璃底 + 3px 语义左边框内嵌，对齐 mini/dock 的液态玻璃语言。
// 单行高度固定 ~37（V10×2 + 文字行高 17），圆角 = 高度 / 2 = 18.5（胶囊）。
class _ToastCapsule extends StatelessWidget {
  const _ToastCapsule({
    required this.palette,
    required this.edge,
    required this.notice,
  });

  final HMusicPalette palette;
  final Color edge;
  final HMusicNotice notice;

  @override
  Widget build(BuildContext context) {
    const vPadding = 10.0;
    const hPadding = 20.0;
    const edgeWidth = 3.0;
    // 固定单行高度 = V10×2 + 文字行高 ~17（13.5 × 1.25 行高），圆角 18.5（胶囊）。
    // 多行文案自然撑高，圆角同比放大保持胶囊形态。
    const singleLineHeight = vPadding * 2 + 17;
    const radius = singleLineHeight / 2;
    return AdaptiveGlassSurface(
      quality: resolveGlassQuality(context),
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: IntrinsicHeight(
          child: Stack(
            children: <Widget>[
              // 内容区：左内边距 = edgeWidth + hPadding，右 = hPadding。
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  edgeWidth + hPadding,
                  vPadding,
                  hPadding,
                  vPadding,
                ),
                child: Text(
                  notice.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    height: 1.25,
                    color: notice.kind == HMusicNoticeKind.error
                        ? palette.danger
                        : palette.textStrong,
                  ),
                ),
              ),
              // 语义左边框：3px 竖条贴左缘，从上到下撑满，内嵌于玻璃之下。
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: edgeWidth,
                child: DecoratedBox(decoration: BoxDecoration(color: edge)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
