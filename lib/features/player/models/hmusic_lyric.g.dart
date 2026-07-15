// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hmusic_lyric.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LyricLine _$LyricLineFromJson(Map<String, dynamic> json) => LyricLine(
  timeMs: (json['timeMs'] as num?)?.toInt() ?? 0,
  text: json['text'] as String? ?? '',
);

Map<String, dynamic> _$LyricLineToJson(LyricLine instance) => <String, dynamic>{
  'timeMs': instance.timeMs,
  'text': instance.text,
};

HMusicLyric _$HMusicLyricFromJson(Map<String, dynamic> json) => HMusicLyric(
  trackId: json['trackId'] as String?,
  source: json['source'] as String?,
  lrc: json['lrc'] as String?,
  lines:
      (json['lines'] as List<dynamic>?)
          ?.map((e) => LyricLine.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$HMusicLyricToJson(HMusicLyric instance) =>
    <String, dynamic>{
      'trackId': ?instance.trackId,
      'source': ?instance.source,
      'lrc': ?instance.lrc,
      'lines': instance.lines,
    };
