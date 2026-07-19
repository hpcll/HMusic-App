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
// 实时分量按播放目标分流——本机取 just_audio 真值；远端设备（音箱）本机
// player 恒为 stopped，取服务端权威状态（playing/position 随远端轮询更新），
// 否则播放页/mini player 在遥控模式下永远显示「已暂停 0:00」。
// 抽成纯函数便于单测，handler 不再内联这段常量。
const List<MediaControl> _controls = <MediaControl>[
  MediaControl.skipToPrevious,
  MediaControl.play,
  MediaControl.pause,
  MediaControl.skipToNext,
  MediaControl.stop,
];

PlaybackState playbackStateProjection({
  required AudioPlayer player,
  required server.HMusicPlaybackState? serverState,
}) {
  if (serverState != null && !serverState.isLocalDevice) {
    final playing = serverState.state == server.PlaybackStatus.playing;
    return PlaybackState(
      controls: _controls,
      systemActions: const <MediaAction>{MediaAction.seek},
      androidCompactActionIndices: const <int>[0, 1, 3],
      processingState: switch (serverState.state) {
        server.PlaybackStatus.loading => AudioProcessingState.loading,
        server.PlaybackStatus.playing ||
        server.PlaybackStatus.paused => AudioProcessingState.ready,
        _ => AudioProcessingState.idle,
      },
      playing: playing,
      updatePosition: Duration(milliseconds: serverState.positionMs),
      bufferedPosition: Duration(milliseconds: serverState.positionMs),
      // 暂停时速度 0：锁屏进度不做外推，避免两次轮询间自己往前爬。
      speed: playing ? 1.0 : 0.0,
      queueIndex: serverState.queueIndex,
    );
  }
  return PlaybackState(
    controls: _controls,
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
