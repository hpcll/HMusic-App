import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../models/hmusic_lyric.dart';
import '../view_models/lyric_view_model.dart';

// 全屏歌词滚动列表（沉浸歌词页复用）：当前行衬线放大加深、上下 mask 渐隐、行点 seek、
// 自动跟随把当前行滚到视口中部（进页即定位）。对齐 docs/04 屏 2b。
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

  // 每行估算高度，用于把当前行滚到视口中部（行高随字号浮动，取平均值够用）。
  static const double _lineExtent = 52;

  @override
  void didUpdateWidget(LyricScrollView old) {
    super.didUpdateWidget(old);
    if (widget.activeLine != old.activeLine) {
      _followActive();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 当前行滚到视口中部：估算目标偏移，平滑滚动。
  void _followActive() {
    if (widget.activeLine < 0 || !_controller.hasClients) return;
    final viewport = _controller.position.viewportDimension;
    final target =
        (widget.activeLine * _lineExtent) - (viewport / 2) + (_lineExtent / 2);
    final max = _controller.position.maxScrollExtent;
    final clamped = target.clamp(0.0, max);
    unawaited(
      _controller.animateTo(
        clamped,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      ),
    );
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
      final lrc = state.lyric?.lrc ?? '';
      if (lrc.isNotEmpty) {
        // 无行级时间戳但有整段 LRC：降级整段展示。
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

    // 上下 mask 渐隐：内容从透明→不透明→透明，聚焦中部当前行。
    return ShaderMask(
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
        padding: const EdgeInsets.symmetric(vertical: 120),
        itemCount: lines.length,
        itemBuilder: (context, i) => _LyricRow(
          line: lines[i],
          active: i == widget.activeLine,
          palette: palette,
          onTap: widget.seekEnabled
              ? () => widget.onLineTap(lines[i].timeMs)
              : null,
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
