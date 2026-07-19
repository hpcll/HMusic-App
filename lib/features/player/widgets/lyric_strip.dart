import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../core/audio/hmusic_audio_handler.dart';
import '../view_models/lyric_view_model.dart';
import '../views/lyrics_page.dart';

// 窄屏播放页染色歌词条（信息与进度条之间）：当前句按行内播放进度左→右渐进填充，
// 点击进沉浸歌词页。对齐 docs/04「必须逐帧驱动」铁律——用 Ticker 每帧读 just_audio
// position 直算 fill 驱动 ShaderMask，不走 setState 每帧重建（定时器 10fps 卡顿、
// CSS transition 换行回扫，web 两坑都踩过）。
class LyricStrip extends ConsumerStatefulWidget {
  const LyricStrip({required this.durationMs, super.key});

  // 当前曲总时长，用于估算末行的染色终点。
  final int durationMs;

  @override
  ConsumerState<LyricStrip> createState() => _LyricStripState();
}

class _LyricStripState extends ConsumerState<LyricStrip>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  // 逐帧直写的染色比例 0..1，不触发 build（染色丝滑靠它，不靠重建）。
  final ValueNotifier<double> _fill = ValueNotifier<double>(0);

  // 当前行索引，仅换行时触发一次文本重建。
  int _lineIndex = -1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame);
    unawaited(_ticker.start());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _fill.dispose();
    super.dispose();
  }

  void _onFrame(Duration _) {
    final handler = ref.read(hmusicAudioHandlerProvider).value;
    final lines = ref.read(lyricViewModelProvider).lines;
    if (handler == null || lines.isEmpty) return;

    // 进度取 handler.effectivePosition 唯一出口：本机逐帧读 just_audio；
    // 远端为服务端校准 + 本地外推，染色连续推进不按轮询步进。
    var pos = handler.effectivePosition.inMilliseconds;
    final durMax = widget.durationMs;
    if (durMax > 0 && pos > durMax) pos = durMax;

    var i = -1;
    for (var k = 0; k < lines.length; k++) {
      if (lines[k].timeMs <= pos) {
        i = k;
      } else {
        break;
      }
    }
    if (i < 0) {
      _fill.value = 0;
      if (_lineIndex != -1) setState(() => _lineIndex = -1);
      return;
    }
    final start = lines[i].timeMs;
    final end = i + 1 < lines.length
        ? lines[i + 1].timeMs
        : (durMax > 0 ? durMax : start + 5000);
    final span = (end - start) < 1 ? 1 : (end - start);
    _fill.value = ((pos - start) / span).clamp(0.0, 1.0);
    // 换行才重建文本；染色比例每帧直写 _fill，不重建组件。
    if (i != _lineIndex) setState(() => _lineIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = ref.watch(lyricViewModelProvider);
    final lines = state.lines;

    final String label;
    final bool karaoke;
    if (state.loading) {
      label = '歌词加载中…';
      karaoke = false;
    } else if (lines.isEmpty) {
      label = (state.lyric?.lrc ?? '').isNotEmpty ? '查看歌词' : '暂无歌词';
      karaoke = false;
    } else if (_lineIndex < 0) {
      label = '…';
      karaoke = false;
    } else {
      final text = lines[_lineIndex].text;
      label = text.isEmpty ? '…' : text;
      karaoke = true;
    }

    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () => context.push(LyricsPage.path),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: const Size.fromHeight(24),
        ),
        child: karaoke
            ? _KaraokeText(
                text: label,
                fill: _fill,
                litColor: palette.textStrong,
                dimColor: palette.muted,
              )
            : Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: palette.muted),
              ),
      ),
    );
  }
}

// 染色文本：ShaderMask 两色硬切渐变，fill 处左染色右灰。对齐 web linear-gradient 硬切。
class _KaraokeText extends StatelessWidget {
  const _KaraokeText({
    required this.text,
    required this.fill,
    required this.litColor,
    required this.dimColor,
  });

  final String text;
  final ValueListenable<double> fill;
  final Color litColor;
  final Color dimColor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: fill,
      builder: (context, value, _) {
        // stop 收进 (0,1) 开区间，避免 0/1 处两色 stop 重合导致渐变退化。
        final stop = value.clamp(0.0001, 0.9999);
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => LinearGradient(
            stops: <double>[stop, stop],
            colors: <Color>[litColor, dimColor],
          ).createShader(rect),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              // ShaderMask srcIn 用文本 alpha 取色，颜色本身须不透明。
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
