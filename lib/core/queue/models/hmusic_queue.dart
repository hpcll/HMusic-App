import 'package:json_annotation/json_annotation.dart';

import '../../audio/models/hmusic_playback_state.dart';
import '../../models/hmusic_track.dart';

part 'hmusic_queue.g.dart';

@JsonSerializable(includeIfNull: false)
class HMusicQueueItem {
  const HMusicQueueItem({
    required this.id,
    required this.track,
    required this.addedAt,
  });

  factory HMusicQueueItem.fromJson(Map<String, Object?> json) =>
      _$HMusicQueueItemFromJson(json);

  final String id;
  final HMusicTrack track;
  final int addedAt;

  Map<String, Object?> toJson() => _$HMusicQueueItemToJson(this);
}

@JsonSerializable(includeIfNull: false)
class HMusicQueue {
  const HMusicQueue({
    required this.sessionId,
    required this.items,
    required this.currentIndex,
    required this.playMode,
    required this.updatedAt,
  });

  factory HMusicQueue.fromJson(Map<String, Object?> json) =>
      _$HMusicQueueFromJson(json);

  final String sessionId;
  final List<HMusicQueueItem> items;
  final int currentIndex;

  @JsonKey(unknownEnumValue: PlayMode.unknown)
  final PlayMode playMode;

  final int updatedAt;

  Map<String, Object?> toJson() => _$HMusicQueueToJson(this);
}
