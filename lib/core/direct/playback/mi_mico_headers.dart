import '../../network/api_failure.dart';
import '../mi_direct_device.dart';
import '../mi_direct_session.dart';

/// S12A 的操作命令沿用旧版实机验证过的官方 Android MICO 请求模板。
Map<String, String> miMicoHeaders(
  MiDirectSession session,
  MiDirectDevice device,
  String instanceId,
) {
  for (final value in [device.id, device.hardware, instanceId]) {
    if (value.isEmpty || RegExp(r'[\x00-\x20\x7f;,]').hasMatch(value)) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        code: 'MI_DIRECT_DEVICE_INVALID',
        message: '音箱设备标识无效，请刷新设备列表',
      );
    }
  }
  return {
    'Cookie':
        '${session.cookie}; hardware=${device.hardware}; deviceId=${device.id}; phoneModel=Android; instanceId=$instanceId',
    'User-Agent':
        'MICO/AndroidApp/@SHIP.TO.2A2FE0D7@/2.8.1 MIBAppVersion/1.13.0',
    'clientexpids': 'sdg',
    'tvbgroupids':
        'de1tB,de1uA,de13C,dfohB,dfonB,dehkC,dejmE,demxA,de7eA,dezbG,deqlA,'
        'deqnA,defwB,ed7h,ed92,eeby,eeqi,eeqk,ed8c,ed8h,eedj,eedl,eedn,'
        'eeei,eesm,ee6i,efk7,efp3,efqb,de7hC,dfx5B,dfyyA,dfy6C,dernC',
    'x-user-level': '1',
  };
}
