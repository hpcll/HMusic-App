import 'dart:ui';

import 'package:flutter/material.dart';

enum GlassQuality { high, medium, off }

// 玻璃档位按环境解析：辅助功能开高对比/减动效 → off（不透明面板底，可读性
// 优先，即无玻璃环境的体面降级）；桌面 GPU 富余 → high；移动 → medium。
GlassQuality resolveGlassQuality(BuildContext context) {
  if (MediaQuery.highContrastOf(context) ||
      MediaQuery.disableAnimationsOf(context)) {
    return GlassQuality.off;
  }
  return switch (Theme.of(context).platform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => GlassQuality.high,
    _ => GlassQuality.medium,
  };
}

// 自适应玻璃面，chrome 专用（导航条 / mini player / 控制浮层）。
// blur 后叠加轻度提饱和 + 顶缘高光，透出的内容通透不发灰；off 档退回不透明
// 面板。内容卡片禁止使用（docs/03：背景层不足时玻璃没有信息价值）。
class AdaptiveGlassSurface extends StatelessWidget {
  const AdaptiveGlassSurface({
    required this.child,
    this.quality = GlassQuality.medium,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.border,
    this.shadow = true,
    this.bottomFade = false,
    super.key,
  });

  final Widget child;
  final GlassQuality quality;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  // 覆盖默认玻璃描边：全宽条形态（radius 0 的顶栏/底栏）只要单边 hairline。
  final BoxBorder? border;

  // 悬浮卡投影；贴边条形态关掉。
  final bool shadow;

  // 全宽条底缘渐隐（顶栏用）：tint 在底部约 1/5 高度内渐隐到透明，抹掉
  // 玻璃区下缘的硬切——chrome 不画常驻分隔线（对齐 dock/mini 无边框胶囊
  // 语言）。off 档忽略：实底面板要保持完整可读边界，分隔交还调用方 hairline。
  final bool bottomFade;

  // 饱和度 1.25 的颜色矩阵（Rec.709 亮度权重）：模糊采样后轻微提饱和。
  static const List<double> _saturate = <double>[
    1.19675, -0.17875, -0.01800, 0, 0, //
    -0.05325, 1.07125, -0.01800, 0, 0, //
    -0.05325, -0.17875, 1.23200, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // tint 从主题背景色衍生而非纯白/纯黑：无内容滚过时玻璃与暖纸背景融为一体
    //（纯白 tint 会在顶栏/底栏处压出一条发白色带），内容滚入时仍有磨砂遮蔽。
    final tint = theme.scaffoldBackgroundColor.withValues(
      alpha: dark ? 0.58 : 0.62,
    );
    final sigma = switch (quality) {
      GlassQuality.high => 28.0,
      GlassQuality.medium => 18.0,
      GlassQuality.off => 0.0,
    };
    // radius 0 时不给 BoxDecoration 传 borderRadius，允许单边非均匀描边。
    final decorationRadius = borderRadius == BorderRadius.zero
        ? null
        : borderRadius;
    // 顶缘高光只给悬浮卡形态：全宽条（radius 0 的顶栏/底栏）要与背景无缝，
    // 高光会把条子压白，观感割裂。
    final showHighlight =
        quality != GlassQuality.off && borderRadius != BorderRadius.zero;
    final highlight = Colors.white.withValues(alpha: dark ? 0.10 : 0.35);
    final fade = bottomFade && quality != GlassQuality.off;
    final baseColor = quality == GlassQuality.off
        ? Theme.of(context).colorScheme.surface
        : tint;
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fade ? null : baseColor,
        // 渐隐 tint：上 80% 全浓度，底部 20% 滑到全透明，玻璃与内容之间
        // 没有亮度台阶，只剩模糊的软边界。
        gradient: fade
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[tint, tint, tint.withValues(alpha: 0)],
                stops: const <double>[0, 0.8, 1],
              )
            : null,
        borderRadius: decorationRadius,
        border:
            border ??
            Border.all(
              color: Colors.white.withValues(alpha: dark ? 0.12 : 0.45),
            ),
        boxShadow: shadow
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 28,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      // 顶缘高光渐变：光从上方来的玻璃质感；off 档是实底，不需要。
      child: DecoratedBox(
        decoration: !showHighlight
            ? const BoxDecoration()
            : BoxDecoration(
                borderRadius: decorationRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[highlight, highlight.withValues(alpha: 0)],
                  stops: const <double>[0, 0.35],
                ),
              ),
        child: Padding(padding: padding, child: child),
      ),
    );
    if (sigma == 0) return surface;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.compose(
          outer: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          inner: const ColorFilter.matrix(_saturate),
        ),
        child: surface,
      ),
    );
  }
}
