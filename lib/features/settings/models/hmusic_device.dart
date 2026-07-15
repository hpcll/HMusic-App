import 'package:json_annotation/json_annotation.dart';

part 'hmusic_device.g.dart';

// 播放设备（GET /devices），字段按 web 使用面建模：
// type=browser 为虚拟本机设备，无可探测硬件能力。
@JsonSerializable(includeIfNull: false)
class HMusicDevice {
  const HMusicDevice({
    required this.id,
    required this.name,
    this.type,
    this.isDefault = false,
    this.isOnline = false,
  });

  factory HMusicDevice.fromJson(Map<String, Object?> json) =>
      _$HMusicDeviceFromJson(json);

  final String id;
  final String name;
  final String? type;

  @JsonKey(defaultValue: false)
  final bool isDefault;

  @JsonKey(defaultValue: false)
  final bool isOnline;

  Map<String, Object?> toJson() => _$HMusicDeviceToJson(this);
}
