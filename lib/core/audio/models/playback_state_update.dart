import '../../models/hmusic_track.dart';
import 'hmusic_playback_state.dart';

extension PlaybackStateUpdate on HMusicPlaybackState {
  HMusicPlaybackState update({
    PlaybackStatus? status,
    String? deviceId,
    String? deviceName,
    HMusicTrack? track,
    int? positionMs,
    int? durationMs,
    num? volume,
    PlayMode? playMode,
    int? queueIndex,
    int? queueLength,
    bool? seekEnabled,
    String? streamUrl,
    bool clearStream = false,
    bool clearTrack = false,
    int? updatedAt,
  }) => HMusicPlaybackState(
    sessionId: sessionId,
    state: status ?? state,
    deviceId: deviceId ?? this.deviceId,
    deviceName: deviceName ?? this.deviceName,
    track: clearTrack ? null : track ?? this.track,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    volume: volume ?? this.volume,
    playMode: playMode ?? this.playMode,
    queueIndex: queueIndex ?? this.queueIndex,
    queueLength: queueLength ?? this.queueLength,
    seekEnabled: seekEnabled ?? this.seekEnabled,
    streamUrl: clearStream ? null : streamUrl ?? this.streamUrl,
    updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
  );
}
