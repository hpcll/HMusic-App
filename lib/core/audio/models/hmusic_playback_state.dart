import 'package:json_annotation/json_annotation.dart';

import '../../models/hmusic_track.dart';

part 'hmusic_playback_state.g.dart';

enum PlaybackStatus { idle, loading, playing, paused, stopped, error, unknown }

enum PlayMode {
  @JsonValue('list_loop')
  listLoop,
  @JsonValue('single_loop')
  singleLoop,
  shuffle,
  sequence,
  @JsonValue('single_once')
  singleOnce,
  unknown,
}

extension PlayModeWire on PlayMode {
  // 发往 Server 的枚举字面量；unknown 只用于解码容错，禁止外发。
  String? get wireName {
    return switch (this) {
      PlayMode.listLoop => 'list_loop',
      PlayMode.singleLoop => 'single_loop',
      PlayMode.shuffle => 'shuffle',
      PlayMode.sequence => 'sequence',
      PlayMode.singleOnce => 'single_once',
      PlayMode.unknown => null,
    };
  }
}

@JsonSerializable(includeIfNull: false)
class HMusicPlaybackState {
  const HMusicPlaybackState({
    required this.sessionId,
    required this.state,
    required this.positionMs,
    required this.durationMs,
    required this.volume,
    required this.playMode,
    required this.queueIndex,
    required this.queueLength,
    required this.seekEnabled,
    required this.updatedAt,
    this.deviceId,
    this.deviceName,
    this.track,
    this.streamUrl,
  });

  factory HMusicPlaybackState.fromJson(Map<String, Object?> json) =>
      _$HMusicPlaybackStateFromJson(json);

  final String sessionId;
  final String? deviceId;
  final String? deviceName;

  // 服务端本机虚拟设备 id（docs/12 C-08：全局单活跃本机客户端）。
  static const String localDeviceId = 'local-browser';

  // 播放目标是否本机。远端（音箱）时本机 player 必须静默，控制命令全部
  // 经服务端转发到设备；deviceId 为空（冷状态未定设备）按远端处理，不动 player。
  bool get isLocalDevice => deviceId == localDeviceId;

  @JsonKey(unknownEnumValue: PlaybackStatus.unknown)
  final PlaybackStatus state;

  final HMusicTrack? track;
  final int positionMs;
  final int durationMs;
  final num volume;

  @JsonKey(unknownEnumValue: PlayMode.unknown)
  final PlayMode playMode;

  final int queueIndex;
  final int queueLength;
  final bool seekEnabled;
  final String? streamUrl;
  final int updatedAt;

  Map<String, Object?> toJson() => _$HMusicPlaybackStateToJson(this);
}
