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

// 遥控进度本地外推（对齐老项目 HMusic 的「服务端校准 + 本地预测」）：
// 远端（音箱）权威进度随 5s 轮询更新，直接消费会让进度条与歌词染色按段步进。
// 服务端状态落地时记「基准进度 + 本地时钟锚点」，读取时按 playing 外推
// 基准 + 流逝时间；轮询落地即是校准——同曲连续播放中 2.5s 内的回跳视为
// 轮询延迟抖动，单调托底不回扫；切歌 / seek / 暂停立即贴齐服务端值。
class RemotePositionProjector {
  server.HMusicPlaybackState? _state;
  DateTime? _anchor;
  String? _trackId;

  // 同曲单调下限：校准落地时用上次估算托底，防止外推领先被轮询值拉回扫。
  int _floorMs = 0;

  static const int _jitterToleranceMs = 2500;

  void sync(server.HMusicPlaybackState state, DateTime now) {
    final lastEstimateMs = estimate(now).inMilliseconds;
    final playingContinues =
        state.track?.id != null &&
        state.track?.id == _trackId &&
        state.state == server.PlaybackStatus.playing &&
        _state?.state == server.PlaybackStatus.playing;
    final backwardMs = lastEstimateMs - state.positionMs;
    _floorMs =
        playingContinues && backwardMs > 0 && backwardMs <= _jitterToleranceMs
        ? lastEstimateMs
        : 0;
    _state = state;
    _anchor = now;
    _trackId = state.track?.id;
  }

  Duration estimate(DateTime now) {
    final state = _state;
    final anchor = _anchor;
    if (state == null || anchor == null) return Duration.zero;
    var ms = state.positionMs;
    if (state.state == server.PlaybackStatus.playing) {
      ms += now.difference(anchor).inMilliseconds;
    }
    if (_floorMs > ms) ms = _floorMs;
    if (state.durationMs > 0 && ms > state.durationMs) ms = state.durationMs;
    return Duration(milliseconds: ms);
  }
}
