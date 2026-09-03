import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/hmusic_palette.dart';
import '../../core/platform_shell/widgets/adaptive_glass_surface.dart';
import '../layout/shell_metrics.dart';
import '../models/hmusic_notice.dart';

OverlayEntry? _entry;
Timer? _timer;
GlobalKey<_ToastAnimatorState>? _animatorKey;

// Toast 提示，Apple Music 式玻璃胶囊：水平居中、内容自适应宽（max 90%）、
// 胶囊形态（高度 / 2 圆角）+ 毛玻璃材质，无 hairline、无左色条——语义改由
// leading 图标承担（成功 ✓ 青绿 / 错误 ⚠ 红 / info 无图标），文字恒墨色。
// 出入场：180ms 淡入 + 上浮 8px，自动消失前 140ms 淡出（减动效时直切）；
// 3.2s 自动消失，新 toast 立即顶替旧 toast。全站轻量结果提示统一走这里，
// 别再用 SnackBar——floating SnackBar 在桌面宽窗会拉成整行黑条。
// 直插 root Overlay + IgnorePointer：不参与页面布局，也不挡底部区域的点击。
// 底距在 web bottom:28/92 基础上避让本壳的底部 chrome（见 _HMusicToast）。
void showHMusicToast(BuildContext context, HMusicNotice notice) {
  final overlay = Overlay.of(context, rootOverlay: true);
  hideHMusicToast();
  final animatorKey = GlobalKey<_ToastAnimatorState>();
  final entry = OverlayEntry(
    builder: (context) =>
        _HMusicToast(notice: notice, animatorKey: animatorKey),
  );
  _entry = entry;
  _animatorKey = animatorKey;
  overlay.insert(entry);
  _timer = Timer(const Duration(milliseconds: 3200), _dismiss);
}

// 立即移除（顶替旧 toast / 页面主动清场用）；自动消失走 _dismiss 的淡出。
void hideHMusicToast() {
  _timer?.cancel();
  _timer = null;
  _animatorKey = null;
  _entry?.remove();
  _entry?.dispose();
  _entry = null;
}

Future<void> _dismiss() async {
  // 淡出期间可能被新 toast 顶替：完成后仅当自己仍是当前条目才移除。
  final entry = _entry;
  await _animatorKey?.currentState?.hide();
  if (_entry == entry) hideHMusicToast();
}

class _HMusicToast extends StatelessWidget {
  const _HMusicToast({required this.notice, required this.animatorKey});

  final HMusicNotice notice;
  final GlobalKey<_ToastAnimatorState> animatorKey;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // 断点 860 与 app_shell 一致。web 的 28/92 是按「底边无 chrome/有底栏」
    // 定的；本壳桌面有悬浮 mini（包络 76），toast 抬到其上再留 12 空隙，且
    // mini 隐藏时保持同一高度，不随播放状态跳动。窄屏按悬浮玻璃 chrome 的
    // 完整包络让位（dock + gap + mini 胶囊 + 呼吸距，原生壳与回退壳同数值），
    // 同样不随播放状态跳动。
    final desktop = size.width >= 860;
    final bottom = desktop
        ? kMiniPlayerDesktopInset + 12
        : chromeBottomOffset(
                MediaQuery.paddingOf(context).bottom,
                platform: Theme.of(context).platform,
              ) +
              kChromeDockHeight +
              kChromeGap +
              kChromeMiniHeight +
              kChromeContentClearance;
    // 桌面居中于侧栏右侧的内容区，而不是整窗——和 mini/页面同一根轴线。
    final contentWidth = desktop ? size.width - kSidebarWidth : size.width;
    return Positioned(
      left: desktop ? kSidebarWidth : 0,
      right: 0,
      bottom: bottom,
      child: IgnorePointer(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth * 0.9),
            child: _ToastAnimator(
              key: animatorKey,
              child: _ToastCapsule(notice: notice),
            ),
          ),
        ),
      ),
    );
  }
}

// 出入场动画：180ms 淡入 + 上浮 8px（easeOutCubic），hide() 140ms 淡出。
// 「减弱动态效果」开启时两个方向都直切，保持 docs/03 的无动画降级。
class _ToastAnimator extends StatefulWidget {
  const _ToastAnimator({required this.child, super.key});

  final Widget child;

  @override
  State<_ToastAnimator> createState() => _ToastAnimatorState();
}

class _ToastAnimatorState extends State<_ToastAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    reverseDuration: const Duration(milliseconds: 140),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.forward());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  Future<void> hide() async {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0;
      return;
    }
    await _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curved.value) * 8),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// 胶囊本体：毛玻璃底、无描边，leading 图标表意。单行高度固定 ~37
//（V10×2 + 文字行高 17），圆角 = 高度 / 2；多行文案自然撑高保持胶囊形态。
class _ToastCapsule extends StatelessWidget {
  const _ToastCapsule({required this.notice});

  final HMusicNotice notice;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const vPadding = 10.0;
    const singleLineHeight = vPadding * 2 + 17;
    const radius = singleLineHeight / 2;
    // (图标, 颜色)：成功沿用 accent 铁律（toast 成功是全站 5 处之一），
    // 错误 danger；info 纯文字不配图标。
    final (IconData, Color)? icon = switch (notice.kind) {
      HMusicNoticeKind.success => (Icons.check_rounded, palette.accent),
      HMusicNoticeKind.error => (Icons.error_outline_rounded, palette.danger),
      HMusicNoticeKind.info => null,
    };
    return AdaptiveGlassSurface(
      quality: resolveGlassQuality(context),
      padding: EdgeInsets.fromLTRB(
        icon == null ? 20 : 14,
        vPadding,
        20,
        vPadding,
      ),
      borderRadius: BorderRadius.circular(radius),
      hairline: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon.$1, size: 16, color: icon.$2),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(
              notice.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13.5,
                height: 1.25,
                color: palette.textStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
