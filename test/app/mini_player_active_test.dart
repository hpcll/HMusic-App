import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/app_providers.dart';
import 'package:hmusic/core/audio/hmusic_audio_handler.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/features/player/view_models/player_view_model.dart';

HMusicPlaybackState _state({HMusicTrack? track}) => HMusicPlaybackState(
  sessionId: 'restored',
  deviceId: HMusicPlaybackState.localDeviceId,
  state: PlaybackStatus.paused,
  positionMs: 0,
  durationMs: 180000,
  volume: 50,
  playMode: PlayMode.listLoop,
  queueIndex: 0,
  queueLength: 1,
  seekEnabled: true,
  updatedAt: 0,
  track: track,
);

void main() {
  test('恢复曲目时壳与播放条同源留高，不依赖本机 MediaItem 已装载', () async {
    final states = StreamController<HMusicPlaybackState>();
    addTearDown(states.close);
    final container = ProviderContainer(
      overrides: [
        serverPlaybackStateProvider.overrideWith((ref) => states.stream),
        hmusicAudioHandlerProvider.overrideWith(
          (ref) => throw StateError('壳占位不得自行读取 handler.mediaItem'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      miniPlayerActiveProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    expect(container.read(miniPlayerActiveProvider), isFalse);
    states.add(
      _state(
        track: const HMusicTrack(
          id: 'track-1',
          source: 'library',
          sourceTrackId: '1',
          title: '恢复的曲目',
          artist: '测试歌手',
        ),
      ),
    );
    await container.read(serverPlaybackStateProvider.future);
    expect(container.read(miniPlayerActiveProvider), isTrue);

    states.add(_state());
    await pumpEventQueue();
    expect(container.read(miniPlayerActiveProvider), isFalse);
  });
}
