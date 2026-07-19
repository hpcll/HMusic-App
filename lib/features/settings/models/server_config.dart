import 'package:json_annotation/json_annotation.dart';

part 'server_config.g.dart';

// 运行配置（GET/PATCH /config）。策略枚举保持字符串透传：
// UI 下拉用常量表映射标签，避免服务端新增策略时客户端解码崩。
@JsonSerializable(includeIfNull: false)
class ServerConfig {
  const ServerConfig({
    required this.serverName,
    required this.defaultQuality,
    required this.searchStrategy,
    required this.resolveStrategy,
    this.extraPlayMusicModels = const <String>[],
    this.manualTracks = const <ManualTrack>[],
    this.announceTracks = false,
  });

  factory ServerConfig.fromJson(Map<String, Object?> json) =>
      _$ServerConfigFromJson(json);

  final String serverName;
  final String defaultQuality;
  final String searchStrategy;
  final String resolveStrategy;

  @JsonKey(defaultValue: <String>[])
  final List<String> extraPlayMusicModels;

  @JsonKey(defaultValue: <ManualTrack>[])
  final List<ManualTrack> manualTracks;

  // 音箱播放前语音播报歌名（仅远端小爱设备生效）。
  @JsonKey(defaultValue: false)
  final bool announceTracks;

  Map<String, Object?> toJson() => _$ServerConfigToJson(this);
}

// 手工曲目条目（config.manualTracks，PATCH 全量替换）。
@JsonSerializable(includeIfNull: false)
class ManualTrack {
  const ManualTrack({required this.title, required this.url, this.artist});

  factory ManualTrack.fromJson(Map<String, Object?> json) =>
      _$ManualTrackFromJson(json);

  final String title;
  final String? artist;
  final String url;

  Map<String, Object?> toJson() => _$ManualTrackToJson(this);
}
