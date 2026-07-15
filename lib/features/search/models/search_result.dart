import 'package:json_annotation/json_annotation.dart';

import '../../../core/models/hmusic_track.dart';

part 'search_result.g.dart';

@JsonSerializable()
class SearchResult {
  const SearchResult({
    required this.query,
    required this.page,
    required this.limit,
    required this.total,
    required this.tracks,
    this.source,
  });

  factory SearchResult.fromJson(Map<String, Object?> json) =>
      _$SearchResultFromJson(json);

  final String query;
  final String? source;
  final int page;
  final int limit;
  final int total;
  final List<HMusicTrack> tracks;

  Map<String, Object?> toJson() => _$SearchResultToJson(this);
}
