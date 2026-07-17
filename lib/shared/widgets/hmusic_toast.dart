import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/hmusic_palette.dart';
import '../layout/shell_metrics.dart';
import '../models/hmusic_notice.dart';

OverlayEntry? _entry;
Timer? _timer;

// docs/03 Toast 规格，对齐 web .toast：水平居中、内容自适应宽（max 90%）、
// panel 底 + hairline + 3px 语义左边框 + shadow-pop、无动画纯出现/消失、
// 3.2s 自动消失，新 toast 顶替旧 toast。全站轻量结果提示统一走这里，别再用
// SnackBar——floating SnackBar 在桌面宽窗会拉成整行黑条，且无法关掉出入场动画。
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
    final dark = Theme.of(context).brightness == Brightness.dark;
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
          child: Container(
            constraints: BoxConstraints(maxWidth: contentWidth * 0.9),
            decoration: BoxDecoration(
              color: palette.panel,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: palette.line),
              // --shadow-pop：7px 15px 36px 4px，暗色加深（.1 → .45）。
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.45 : 0.10),
                  offset: const Offset(7, 15),
                  blurRadius: 36,
                  spreadRadius: 4,
                ),
              ],
            ),
            // 语义条盖在 hairline 之上并跟着圆角裁切；BoxDecoration 不允许
            // 非均匀 border 配圆角，只能这样叠。左内边距 23 = 3 语义条 + 20。
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(23, 10, 20, 10),
                    child: Text(
                      notice.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13.5,
                        color: notice.kind == HMusicNoticeKind.error
                            ? palette.danger
                            : palette.textStrong,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 3,
                    child: ColoredBox(color: edge),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
