import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/platform/client_playback_capabilities.dart';
import '../view_models/player_view_model.dart';
import 'player_volume_row.dart';

// 本机连续提交，音箱仅松手提交。按目标 key 重建拖动态，避免两台设备串音量。
class PlayerTargetVolume extends ConsumerWidget {
  const PlayerTargetVolume({required this.state, super.key});

  final HMusicPlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playerViewModelProvider);
    if (!state.isLocalDevice) {
      return PlayerVolumeRow(
        key: ValueKey('volume-${state.deviceId}'),
        initialVolume: (state.volume / 100).clamp(0, 1).toDouble(),
        enabled: state.deviceId != null,
        onChanged: (_) {},
        onChangeEnd: (value) =>
            controller.setDeviceVolume((value * 100).round()),
      );
    }
    if (!ref.watch(clientPlaybackCapabilitiesProvider).supportsLocalPlayback) {
      return PlayerVolumeRow(
        initialVolume: 0,
        enabled: false,
        onChanged: (_) {},
      );
    }
    return ref
        .watch(hmusicAudioHandlerProvider)
        .maybeWhen(
          data: (handler) => StreamBuilder<double>(
            stream: handler.player.volumeStream,
            initialData: handler.player.volume,
            builder: (context, snapshot) => PlayerVolumeRow(
              key: const ValueKey('volume-local'),
              initialVolume: snapshot.data ?? 1,
              onChanged: controller.setLocalVolume,
            ),
          ),
          orElse: () => PlayerVolumeRow(
            initialVolume: 0,
            enabled: false,
            onChanged: (_) {},
          ),
        );
  }
}
