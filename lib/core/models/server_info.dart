import 'package:json_annotation/json_annotation.dart';

part 'server_info.g.dart';

@JsonSerializable()
class ServerInfo {
  const ServerInfo({
    required this.name,
    required this.version,
    required this.apiVersion,
    this.minAppVersion = '',
    this.capabilities = const <String, bool>{},
  });

  factory ServerInfo.fromJson(Map<String, Object?> json) =>
      _$ServerInfoFromJson(json);

  final String name;
  final String version;
  final String apiVersion;

  // 服务端要求的最低 App 版本（'' / '0.0.0' = 不强制）；旧服务端无此字段。
  final String minAppVersion;
  final Map<String, bool> capabilities;

  Map<String, Object?> toJson() => _$ServerInfoToJson(this);
}
