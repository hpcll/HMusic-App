import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../models/hmusic_lyric.dart';
import '../view_models/lyric_view_model.dart';

// 全屏歌词滚动列表（沉浸歌词页复用）：当前行衬线放大加深、上下 mask 渐隐、行点 seek、
// 自动跟随把当前行钉在视口中线略偏上（真实几何定位，进页即定位）。对齐 docs/04 屏 2b。
class LyricScrollView extends ConsumerStatefulWidget {
  const LyricScrollView({
    required this.activeLine,
    required this.seekEnabled,
    required this.onLineTap,
    super.key,
  });

  // 当前行索引（由父页按播放位置算好传入），-1 表示尚无当前行。
  final int activeLine;

  // seekEnabled 时行点跳转生效，否则纯展示。
  final bool seekEnabled;

  // 点击某行 → seek 到该行 timeMs。
  final void Function(int timeMs) onLineTap;

  @override
  ConsumerState<LyricScrollView> createState() => _LyricScrollViewState();
}

class _LyricScrollViewState extends ConsumerState<LyricScrollView> {
  final ScrollController _controller = ScrollController();

  // 当前行挂这把 GlobalKey，ensureVisible 按真实渲染几何定位。此前按固定 52
  // 估算行高（真实约 42）且漏算列表 padding，误差逐行累积，唱到中段当前行
  // 就漂到视口顶部；真实几何对折行、字号动画也天然免疫。
  final GlobalKey _activeKey = GlobalKey();

  // 对齐系数（0 顶、1 底）：0.4 把当前行钉在视口中线略偏上，读词视线更自然。
  static const double _alignment = 0.4;

  // 粗定位估算行高：仅当目标行离视口太远、尚未被 ListView 物化（进页/seek
  // 大跳）时先跳到附近，物化后下一帧再按真实几何校正。
  static const double _lineExtent = 42;

  // 首次拿到歌词行时立即落位（进页/异步加载完成都会走到），只做一次。
  bool _didInitialFollow = false;

  @override
  void didUpdateWidget(LyricScrollView old) {
    super.didUpdateWidget(old);
    if (widget.activeLine != old.activeLine) {
      // 等本帧子树重建完（GlobalKey 已挪到新当前行）再量几何。
      WidgetsBinding.instance.addPostFrameCallback((_) => _followActive());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 当前行滚到视口中线略偏上。secondPass 标记校正帧，防目标行物化不出来时死循环。
  void _followActive({bool animate = true, bool secondPass = false}) {
    if (!mounted || widget.activeLine < 0 || !_controller.hasClients) return;
    final lineContext = _activeKey.currentContext;
    if (lineContext != null) {
      unawaited(
        Scrollable.ensureVisible(
          lineContext,
          alignment: _alignment,
          duration: animate ? const Duration(milliseconds: 320) : Duration.zero,
          curve: Curves.easeOutCubic,
        ),
      );
      return;
    }
    if (secondPass) return;
    // 目标行未物化：按估算跳到附近逼 ListView 把它建出来，下一帧精确校正。
    final viewport = _controller.position.viewportDimension;
    final rough =
        viewport * _alignment + // 列表顶部 padding（随视口等比，见 build）
        widget.activeLine * _lineExtent -
        (viewport - _lineExtent) * _alignment;
    _controller.jumpTo(rough.clamp(0.0, _controller.position.maxScrollExtent));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followActive(animate: false, secondPass: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = ref.watch(lyricViewModelProvider);
    final lines = state.lines;

    if (state.loading) {
      return _placeholder(palette, '歌词加载中…', '');
    }
    if (lines.isEmpty) {
      // 无行级时间戳但有整段 LRC：剥掉 [标签] 后降级整段展示（旧服务端可能
      // 返回未解析的带标签原文，不能把 [00:00:00] 裸露给用户）。
      final lrc = (state.lyric?.lrc ?? '')
          .replaceAll(RegExp(r'\[[^\]]*\]'), '')
          .trim();
      if (lrc.isNotEmpty) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Text(
            lrc,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.9, color: palette.muted),
          ),
        );
      }
      return _placeholder(palette, '暂无歌词', '纯音乐或该音源没有提供歌词');
    }

    // 歌词行已就绪：下一帧直接落位（进页带缓存 / 异步拉完都在这兜住）。
    if (!_didInitialFollow) {
      _didInitialFollow = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _followActive(animate: false);
      });
    }

    // 上下 mask 渐隐：内容从透明→不透明→透明，聚焦中部当前行。
    // 首尾 padding 随视口等比（顶 40%、底 60%），保证第一句/最后一句也能
    // 停在中线略偏上的锚点位，而不是被列表边界顶走。
    return LayoutBuilder(
      builder: (context, constraints) => ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: <double>[0.0, 0.12, 0.88, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          controller: _controller,
          padding: EdgeInsets.only(
            top: constraints.maxHeight * _alignment,
            bottom: constraints.maxHeight * (1 - _alignment),
          ),
          itemCount: lines.length,
          itemBuilder: (context, i) => _LyricRow(
            key: i == widget.activeLine ? _activeKey : null,
            line: lines[i],
            active: i == widget.activeLine,
            palette: palette,
            onTap: widget.seekEnabled
                ? () => widget.onLineTap(lines[i].timeMs)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _placeholder(HMusicPalette palette, String title, String sub) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.music_note_rounded, size: 40, color: palette.muted),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 15, color: palette.mutedStrong),
          ),
          if (sub.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(fontSize: 12.5, color: palette.muted)),
          ],
        ],
      ),
    );
  }
}

// 单行歌词：当前行衬线放大加深，其余 muted 常规。行点 seek（seekEnabled 时）。
class _LyricRow extends StatelessWidget {
  const _LyricRow({
    required this.line,
    required this.active,
    required this.palette,
    this.onTap,
    super.key,
  });

  final LyricLine line;
  final bool active;
  final HMusicPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          style: active
              ? TextStyle(
                  fontFamily: 'NotoSerifSC',
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: palette.textStrong,
                )
              : TextStyle(fontSize: 15.5, height: 1.4, color: palette.muted),
          textAlign: TextAlign.center,
          child: Text(line.text.isEmpty ? '…' : line.text),
        ),
      ),
    );
  }
}
