// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchResult _$SearchResultFromJson(Map<String, dynamic> json) => SearchResult(
  query: json['query'] as String,
  page: (json['page'] as num).toInt(),
  limit: (json['limit'] as num).toInt(),
  total: (json['total'] as num).toInt(),
  tracks: (json['tracks'] as List<dynamic>)
      .map((e) => HMusicTrack.fromJson(e as Map<String, dynamic>))
      .toList(),
  source: json['source'] as String?,
);

Map<String, dynamic> _$SearchResultToJson(SearchResult instance) =>
    <String, dynamic>{
      'query': instance.query,
      'source': instance.source,
      'page': instance.page,
      'limit': instance.limit,
      'total': instance.total,
      'tracks': instance.tracks,
    };
