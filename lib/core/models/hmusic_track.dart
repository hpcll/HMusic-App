import 'package:json_annotation/json_annotation.dart';

part 'hmusic_track.g.dart';

@JsonSerializable(includeIfNull: false)
class HMusicTrack {
  const HMusicTrack({
    required this.id,
    required this.source,
    required this.sourceTrackId,
    required this.title,
    required this.artist,
    this.album,
    this.durationMs,
    this.coverUrl,
    this.url,
    this.qualities = const <String>[],
    this.raw,
  });

  factory HMusicTrack.fromJson(Map<String, Object?> json) =>
      _$HMusicTrackFromJson(json);

  final String id;
  final String source;
  final String sourceTrackId;
  final String title;
  final String artist;
  final String? album;
  final int? durationMs;
  final String? coverUrl;
  final String? url;
  final List<String> qualities;
  final Object? raw;

  Map<String, Object?> toJson() => _$HMusicTrackToJson(this);
}
