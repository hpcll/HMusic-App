import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../core/audio/models/hmusic_playback_state.dart';
import '../../../../shared/widgets/hmusic_card.dart';
import '../../../../shared/widgets/state_dot.dart';
import '../../view_models/diag_view_model.dart';
import 'settings_field.dart';

// 链路诊断子页：① 测试音（不依赖音源插件）② TTS 播报。
// 状态行 3s 轮询 /playback/state，轮询随本子页生命周期开关。
class DiagSectionView extends ConsumerStatefulWidget {
  const DiagSectionView({super.key});

  @override
  ConsumerState<DiagSectionView> createState() => _DiagSectionViewState();
}

class _DiagSectionViewState extends ConsumerState<DiagSectionView> {
  final TextEditingController _ttsText = TextEditingController(
    text: '你好，我是 HMusic',
  );
  // dispose 里禁止用 ref（unmount 后 ref 抛错），notifier 在 init 时缓存到字段。
  late final DiagViewModel _diag;

  @override
  void initState() {
    super.initState();
    _diag = ref.read(diagViewModelProvider.notifier);
    unawaited(
      Future<void>.microtask(() {
        // microtask 落地前子页可能已销毁：dispose 的 stopPolling 先跑（空操作），
        // 这里再启动就成了没人能停的幽灵轮询。
        if (!mounted) return;
        _diag.startPolling();
      }),
    );
  }

  @override
  void dispose() {
    _diag.stopPolling();
    _ttsText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = ref.watch(diagViewModelProvider);
    final notifier = ref.read(diagViewModelProvider.notifier);
    final playback = state.playback;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HMusicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SettingsCardTitle('① 播放链路'),
              const SizedBox(height: 6),
              Text(
                '向默认音箱播放 3 秒内置测试音，不依赖任何音源插件。',
                style: TextStyle(
                  fontSize: 12,
                  color: palette.muted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: state.busyKind == 'tone'
                    ? null
                    : notifier.playTestTone,
                child: const Text('播放测试音频'),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  StateDot(playback?.state ?? PlaybackStatus.idle),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _statusLine(playback),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: palette.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        HMusicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SettingsCardTitle('② 语音播报（TTS）'),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _ttsText,
                      onSubmitted: (_) => notifier.speak(_ttsText.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: state.busyKind == 'tts'
                        ? null
                        : () => notifier.speak(_ttsText.text),
                    child: const Text('播报'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '两步都能出声，说明服务端 → 小爱音箱链路完全正常。',
          style: TextStyle(fontSize: 12, color: palette.muted, height: 1.6),
        ),
      ],
    );
  }

  String _statusLine(HMusicPlaybackState? playback) {
    if (playback == null) return 'idle';
    final buffer = StringBuffer(playback.state.name);
    final device = playback.deviceName;
    if (device != null && device.isNotEmpty) buffer.write(' · $device');
    if (playback.durationMs > 0) {
      final position = (playback.positionMs / 1000).round();
      final duration = (playback.durationMs / 1000).round();
      buffer.write(' · $position s / $duration s');
    }
    return buffer.toString();
  }
}
