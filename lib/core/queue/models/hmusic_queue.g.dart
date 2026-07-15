// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hmusic_queue.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HMusicQueueItem _$HMusicQueueItemFromJson(Map<String, dynamic> json) =>
    HMusicQueueItem(
      id: json['id'] as String,
      track: HMusicTrack.fromJson(json['track'] as Map<String, dynamic>),
      addedAt: (json['addedAt'] as num).toInt(),
    );

Map<String, dynamic> _$HMusicQueueItemToJson(HMusicQueueItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'track': instance.track,
      'addedAt': instance.addedAt,
    };

HMusicQueue _$HMusicQueueFromJson(Map<String, dynamic> json) => HMusicQueue(
  sessionId: json['sessionId'] as String,
  items: (json['items'] as List<dynamic>)
      .map((e) => HMusicQueueItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  currentIndex: (json['currentIndex'] as num).toInt(),
  playMode: $enumDecode(
    _$PlayModeEnumMap,
    json['playMode'],
    unknownValue: PlayMode.unknown,
  ),
  updatedAt: (json['updatedAt'] as num).toInt(),
);

Map<String, dynamic> _$HMusicQueueToJson(HMusicQueue instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'items': instance.items,
      'currentIndex': instance.currentIndex,
      'playMode': _$PlayModeEnumMap[instance.playMode]!,
      'updatedAt': instance.updatedAt,
    };

const _$PlayModeEnumMap = {
  PlayMode.listLoop: 'list_loop',
  PlayMode.singleLoop: 'single_loop',
  PlayMode.shuffle: 'shuffle',
  PlayMode.sequence: 'sequence',
  PlayMode.singleOnce: 'single_once',
  PlayMode.unknown: 'unknown',
};
