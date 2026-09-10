import 'mi_direct_device.dart';

class MiDirectAccount {
  MiDirectAccount({required this.userId, required List<MiDirectDevice> devices})
    : devices = List.unmodifiable(devices);

  final String userId;
  final List<MiDirectDevice> devices;
}
