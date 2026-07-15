import 'package:json_annotation/json_annotation.dart';

part 'hmusic_lyric.g.dart';

// 单行歌词（LRC 行级时间戳 + 文本）。timeMs 为该行起始毫秒。
@JsonSerializable(includeIfNull: false)
class LyricLine {
  const LyricLine({required this.timeMs, required this.text});

  factory LyricLine.fromJson(Map<String, Object?> json) =>
      _$LyricLineFromJson(json);

  @JsonKey(defaultValue: 0)
  final int timeMs;

  @JsonKey(defaultValue: '')
  final String text;

  Map<String, Object?> toJson() => _$LyricLineToJson(this);
}

// 歌词（POST /tracks/lyrics）。lines 为空但 lrc 非空时降级整段展示；两者皆空即无歌词。
@JsonSerializable(includeIfNull: false)
class HMusicLyric {
  const HMusicLyric({
    this.trackId,
    this.source,
    this.lrc,
    this.lines = const <LyricLine>[],
  });

  factory HMusicLyric.fromJson(Map<String, Object?> json) =>
      _$HMusicLyricFromJson(json);

  final String? trackId;
  final String? source;

  // 原始 LRC 全文，行级解析失败时兜底整段展示。
  final String? lrc;

  @JsonKey(defaultValue: <LyricLine>[])
  final List<LyricLine> lines;

  bool get hasTimedLines => lines.isNotEmpty;

  Map<String, Object?> toJson() => _$HMusicLyricToJson(this);
}
