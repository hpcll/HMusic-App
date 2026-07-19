import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/platform_shell/widgets/adaptive_glass_surface.dart';

// 顶部滚动消融（对齐 Apple Music）：App 不设常驻顶栏，内容滚进状态栏区时
// 被渐进模糊 + 背景色纱帘连续地「揉」进顶缘——内容始终可见，没有条、没有
// 线，也没有不透明色带的「被遮挡」感。
//
// 模糊是真·逐像素渐进（shaders/top_edge_blur.frag + ImageFilter.shader）：
// 半径随高度连续衰减到 0，结构上不存在「带」，也就没有缝——此前用多条
// backdrop 分段近似，每条带都会在裁剪边自造一条线（核在边界外无数据只能
// clamp 外推 + 模糊量一阶跳变），条数只决定线的数量与深浅，到不了零。
// 纱帘是无拐点的连续 ease-out 落差曲线，不存在「恒定段转斜坡」的马赫带。
//
// 回退链：非 Impeller 后端（ImageFilter.isShaderFilterSupported=false，如
// Windows/Linux 窄窗）与 shader 异步编译完成前 → 纯纱帘（同样零缝，只是
// 无磨砂）；off 档（高对比/减动效）→ 不透明渐变，可读性优先于透视。
// 静止时模糊与纱帘采样的都是纯背景，视觉上完全隐形；IgnorePointer 让位点击。
class TopEdgeScrim extends StatefulWidget {
  const TopEdgeScrim({super.key});

  @override
  State<TopEdgeScrim> createState() => _TopEdgeScrimState();
}

class _TopEdgeScrimState extends State<TopEdgeScrim> {
  // 纱帘/模糊的衰减尾巴（安全区之外的延伸段）：对齐 Apple——模糊在状态栏
  // 下方就开始起势，长斜坡缓入，不是「进了状态栏才糊」。曲线是 t³（shader
  // 内）：顶部重涂抹、尾部快速趋零，静止时首屏标题（top+24）处半径
  // ≈0.2~0.3px，低于 shader 的 0.75px 截断阈值，完全不糊；同色纱帘约 10%，
  // 首屏可读性不变。改半径/尾长时必须重算这条静止保护线。
  static const double _tail = 44;
  static const double _blurTail = 44;

  // 顶缘最大采样半径（逻辑像素），运行时乘 DPR。22 对齐 Apple 顶部的重度
  // 涂抹（10 太含蓄，高分屏上与旧方案一眼难辨）。
  static const double _maxBlurRadius = 22;

  // 无拐点的 ease-out 落差曲线：顶部 0.34，连续滑到 0。
  static const List<double> _tintStops = <double>[0, 0.35, 0.6, 0.8, 0.93, 1];
  static const List<double> _tintAlphas = <double>[
    0.34,
    0.30,
    0.20,
    0.10,
    0.035,
    0,
  ];

  // FragmentProgram 进程内只编译一次，所有 scrim 实例共享。
  static Future<ui.FragmentProgram>? _programFuture;

  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    if (ui.ImageFilter.isShaderFilterSupported) {
      _programFuture ??= ui.FragmentProgram.fromAsset(
        'shaders/top_edge_blur.frag',
      );
      unawaited(
        _programFuture!
            .then((program) {
              if (!mounted) return;
              setState(() => _shader = program.fragmentShader());
            })
            .catchError((Object error) {
              // 资产未打包（hot reload 旧进程装不进新 shader）或编译失败：
              // 停留在纯纱帘回退。shader/pubspec 资产变更必须冷启动重新构建。
              debugPrint('TopEdgeScrim: 渐进模糊 shader 加载失败，退纯纱帘 -> $error');
            }),
      );
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    final safeTop = MediaQuery.paddingOf(context).top;
    if (resolveGlassQuality(context) == GlassQuality.off) {
      final height = safeTop + 16;
      return IgnorePointer(
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  background,
                  background,
                  background.withValues(alpha: 0),
                ],
                stops: <double>[0, safeTop / height, 1],
              ),
            ),
          ),
        ),
      );
    }
    final height = safeTop + _tail;
    final veil = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            for (final alpha in _tintAlphas)
              background.withValues(alpha: alpha),
          ],
          stops: _tintStops,
        ),
      ),
    );
    final shader = _shader;
    if (shader == null) {
      return IgnorePointer(
        child: SizedBox(width: double.infinity, height: height, child: veil),
      );
    }
    // uniform 0/1 是引擎注入的纹理尺寸 vec2，自定义 uniform 从下标 2 起。
    // 衰减区与半径都传绝对物理像素：shader 内不依赖纹理尺寸做归一化
    //（backdrop 纹理口径可能大于裁剪区，见 .frag 注释）。
    final dpr = MediaQuery.devicePixelRatioOf(context);
    shader
      ..setFloat(2, (safeTop + _blurTail) * dpr)
      ..setFloat(3, _maxBlurRadius * dpr);
    return IgnorePointer(
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.shader(shader),
            child: veil,
          ),
        ),
      ),
    );
  }
}
