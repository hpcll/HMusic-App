import 'package:json_annotation/json_annotation.dart';

part 'server_info.g.dart';

@JsonSerializable()
class ServerInfo {
  const ServerInfo({
    required this.name,
    required this.version,
    required this.apiVersion,
    this.capabilities = const <String, bool>{},
  });

  factory ServerInfo.fromJson(Map<String, Object?> json) =>
      _$ServerInfoFromJson(json);

  final String name;
  final String version;
  final String apiVersion;
  final Map<String, bool> capabilities;

  Map<String, Object?> toJson() => _$ServerInfoToJson(this);
}
