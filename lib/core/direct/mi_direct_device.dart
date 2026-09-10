import 'mi_hardware_profile.dart';

class MiDirectDevice {
  const MiDirectDevice({
    required this.id,
    required this.did,
    required this.name,
    required this.hardware,
    this.ip,
    this.extraPlayMusicModels = const [],
  });

  factory MiDirectDevice.fromJson(Map<String, dynamic> json) => MiDirectDevice(
    id: json['deviceID']?.toString() ?? '',
    did: json['miotDID']?.toString() ?? '',
    name: (json['alias'] ?? json['name'] ?? '小爱音箱').toString(),
    hardware: json['hardware']?.toString() ?? '',
    ip: (json['localip'] ?? json['localIp'] ?? json['ip'])?.toString(),
  );

  final String id;
  final String did;
  final String name;
  final String hardware;
  final String? ip;
  final List<String> extraPlayMusicModels;

  MiHardwareProfile get profile =>
      MiHardwareProfile(hardware, extraModels: extraPlayMusicModels);

  MiDirectDevice withExtraModels(List<String> models) => MiDirectDevice(
    id: id,
    did: did,
    name: name,
    hardware: hardware,
    ip: ip,
    extraPlayMusicModels: models,
  );
}
