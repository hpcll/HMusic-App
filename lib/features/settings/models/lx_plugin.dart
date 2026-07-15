import 'package:json_annotation/json_annotation.dart';

part 'lx_plugin.g.dart';

// LX 音源插件（对齐 web /sources/lx-plugins 列表项）。列表接口不带 code，
// code 单独走 GET /lx-plugins/:id 取；sourceUrl 非空表示订阅导入、可一键更新。
@JsonSerializable(includeIfNull: false)
class LxPlugin {
  const LxPlugin({
    required this.id,
    required this.name,
    this.enabled = true,
    this.defaultQuality = '320k',
    this.sourceUrl,
  });

  factory LxPlugin.fromJson(Map<String, Object?> json) =>
      _$LxPluginFromJson(json);

  final String id;
  final String name;

  // web 语义：缺省视为启用，只有显式 false 才停用。
  @JsonKey(defaultValue: true)
  final bool enabled;

  @JsonKey(defaultValue: '320k')
  final String defaultQuality;

  final String? sourceUrl;

  Map<String, Object?> toJson() => _$LxPluginToJson(this);
}

// GET /sources 的 health 状态：ok/failed/其它 → 状态点用色。
enum SourceHealth { ok, failed, unknown }

// 订阅链接拉取结果（POST /lx-plugins/fetch）：预填表单用。
class LxFetchResult {
  const LxFetchResult({required this.code, this.name, this.version});

  factory LxFetchResult.fromJson(Map<String, Object?> json) {
    final meta = json['meta'];
    final metaMap = meta is Map<String, Object?>
        ? meta
        : const <String, Object?>{};
    return LxFetchResult(
      code: '${json['code'] ?? ''}',
      name: metaMap['name'] as String?,
      version: metaMap['version']?.toString(),
    );
  }

  final String code;
  final String? name;
  final String? version;
}
