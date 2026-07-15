import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/hmusic_track.dart';
import 'models/hmusic_playback_state.dart' as server;

// 把 Track 映射成 audio_service 的 MediaItem：extras 只放展示用来源标识，
// 禁止放 token 或签名 URL（见 docs/08 §10）。
MediaItem mediaItemForTrack(HMusicTrack track) {
  return MediaItem(
    id: track.id,
    title: track.title,
    artist: track.artist,
    album: track.album,
    artUri: track.coverUrl == null ? null : Uri.tryParse(track.coverUrl!),
    duration: track.durationMs == null
        ? null
        : Duration(milliseconds: track.durationMs!),
    extras: <String, Object?>{
      'source': track.source,
      'sourceTrackId': track.sourceTrackId,
    },
  );
}

// 把 just_audio 的 processingState 投影成 audio_service 的 AudioProcessingState。
AudioProcessingState audioProcessingStateFor(ProcessingState state) {
  return switch (state) {
    ProcessingState.idle => AudioProcessingState.idle,
    ProcessingState.loading => AudioProcessingState.loading,
    ProcessingState.buffering => AudioProcessingState.buffering,
    ProcessingState.ready => AudioProcessingState.ready,
    ProcessingState.completed => AudioProcessingState.completed,
  };
}

// 锁屏/通知 PlaybackState 是两侧状态的投影：按钮集与系统动作固定，
// 实时分量（playing/position/buffer/processingState/queueIndex）从 player 与 server state 取。
// 抽成纯函数便于单测，handler 不再内联这段常量。
PlaybackState playbackStateProjection({
  required AudioPlayer player,
  required server.HMusicPlaybackState? serverState,
}) {
  return PlaybackState(
    controls: const <MediaControl>[
      MediaControl.skipToPrevious,
      MediaControl.play,
      MediaControl.pause,
      MediaControl.skipToNext,
      MediaControl.stop,
    ],
    systemActions: const <MediaAction>{MediaAction.seek},
    androidCompactActionIndices: const <int>[0, 1, 3],
    processingState: audioProcessingStateFor(player.processingState),
    playing: player.playing,
    updatePosition: player.position,
    bufferedPosition: player.bufferedPosition,
    speed: player.speed,
    queueIndex: serverState?.queueIndex,
  );
}
