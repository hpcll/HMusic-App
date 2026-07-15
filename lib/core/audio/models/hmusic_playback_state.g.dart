// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hmusic_playback_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HMusicPlaybackState _$HMusicPlaybackStateFromJson(Map<String, dynamic> json) =>
    HMusicPlaybackState(
      sessionId: json['sessionId'] as String,
      state: $enumDecode(
        _$PlaybackStatusEnumMap,
        json['state'],
        unknownValue: PlaybackStatus.unknown,
      ),
      positionMs: (json['positionMs'] as num).toInt(),
      durationMs: (json['durationMs'] as num).toInt(),
      volume: json['volume'] as num,
      playMode: $enumDecode(
        _$PlayModeEnumMap,
        json['playMode'],
        unknownValue: PlayMode.unknown,
      ),
      queueIndex: (json['queueIndex'] as num).toInt(),
      queueLength: (json['queueLength'] as num).toInt(),
      seekEnabled: json['seekEnabled'] as bool,
      updatedAt: (json['updatedAt'] as num).toInt(),
      deviceId: json['deviceId'] as String?,
      deviceName: json['deviceName'] as String?,
      track: json['track'] == null
          ? null
          : HMusicTrack.fromJson(json['track'] as Map<String, dynamic>),
      streamUrl: json['streamUrl'] as String?,
    );

Map<String, dynamic> _$HMusicPlaybackStateToJson(
  HMusicPlaybackState instance,
) => <String, dynamic>{
  'sessionId': instance.sessionId,
  'deviceId': ?instance.deviceId,
  'deviceName': ?instance.deviceName,
  'state': _$PlaybackStatusEnumMap[instance.state]!,
  'track': ?instance.track,
  'positionMs': instance.positionMs,
  'durationMs': instance.durationMs,
  'volume': instance.volume,
  'playMode': _$PlayModeEnumMap[instance.playMode]!,
  'queueIndex': instance.queueIndex,
  'queueLength': instance.queueLength,
  'seekEnabled': instance.seekEnabled,
  'streamUrl': ?instance.streamUrl,
  'updatedAt': instance.updatedAt,
};

const _$PlaybackStatusEnumMap = {
  PlaybackStatus.idle: 'idle',
  PlaybackStatus.loading: 'loading',
  PlaybackStatus.playing: 'playing',
  PlaybackStatus.paused: 'paused',
  PlaybackStatus.stopped: 'stopped',
  PlaybackStatus.error: 'error',
  PlaybackStatus.unknown: 'unknown',
};

const _$PlayModeEnumMap = {
  PlayMode.listLoop: 'list_loop',
  PlayMode.singleLoop: 'single_loop',
  PlayMode.shuffle: 'shuffle',
  PlayMode.sequence: 'sequence',
  PlayMode.singleOnce: 'single_once',
  PlayMode.unknown: 'unknown',
};
