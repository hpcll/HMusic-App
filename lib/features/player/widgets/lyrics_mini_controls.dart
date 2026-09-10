import 'package:flutter/material.dart';

import '../../../core/audio/models/hmusic_playback_state.dart';
import 'player_seek_bar.dart';
import 'player_transport_controls.dart';

// 沉浸歌词与完整播放器复用同一进度、播控和平台能力绑定。
class LyricsMiniControls extends StatelessWidget {
  const LyricsMiniControls({required this.state, super.key});

  final HMusicPlaybackState state;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PlayerSeekBar(state: state),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: PlayerTransportControls(
            state: state,
            showSecondaryControls: false,
          ),
        ),
      ],
    ),
  );
}
