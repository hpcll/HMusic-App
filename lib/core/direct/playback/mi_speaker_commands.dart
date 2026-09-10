import 'dart:convert';

import '../../network/api_failure.dart';
import '../mi_direct_device.dart';
import '../mi_direct_session.dart';
import '../mi_mina_client.dart';
import 'mi_speaker_status.dart';

class MiSpeakerCommands {
  const MiSpeakerCommands({
    required MiMinaClient client,
    required this.instanceId,
  }) : _client = client;
  final MiMinaClient _client;
  final String instanceId;

  Future<void> operation(
    MiDirectSession session,
    MiDirectDevice device,
    String action,
  ) async {
    for (final media in ['app_ios', 'app_android', 'common', null]) {
      final message = <String, Object?>{
        'action': action,
        if (media != null) 'media': media,
      };
      if (device.profile.needsStopOnPause) {
        try {
          await _client.officialOperation(
            session,
            device: device,
            instanceId: instanceId,
            message: message,
          );
          return;
        } on ApiFailure catch (failure) {
          if (failure.code != 'MI_DIRECT_REJECTED') rethrow;
        }
      }
      try {
        await _client.ubus(
          session,
          deviceId: device.id,
          method: 'player_play_operation',
          message: message,
        );
        return;
      } on ApiFailure catch (failure) {
        // 只有服务端明确拒绝才切换兼容负载；超时可能已经执行，不能重复操作。
        if (failure.code != 'MI_DIRECT_REJECTED' || media == null) rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> status(
    MiDirectSession session,
    MiDirectDevice device,
  ) async {
    for (final media in [null, 'app_android', 'app_ios']) {
      Object? result;
      try {
        result = await _client.ubus(
          session,
          deviceId: device.id,
          method: 'player_get_play_status',
          message: {if (media != null) 'media': media},
        );
      } on ApiFailure catch (failure) {
        if (failure.code != 'MI_DIRECT_REJECTED') rethrow;
        continue;
      }
      if (result is! Map<String, dynamic>) continue;
      Object? info = result.containsKey('info') ? result['info'] : result;
      if (info is String) {
        try {
          info = jsonDecode(info);
        } on FormatException {
          continue;
        }
      }
      if (info is Map<String, dynamic>) {
        final parsed = MiSpeakerStatus(info);
        if (parsed.status != null ||
            parsed.volume != null ||
            parsed.positionMs != null) {
          return info;
        }
      }
    }
    throw const ApiFailure(
      kind: ApiFailureKind.invalidResponse,
      code: 'MI_DIRECT_STATUS_INVALID',
      message: '音箱未返回有效的播放状态',
    );
  }

  Future<void> seek(
    MiDirectSession session,
    MiDirectDevice device,
    int positionMs,
  ) async {
    if (!device.profile.supportsSeek || positionMs < 0) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        code: 'MI_DIRECT_SEEK_UNAVAILABLE',
        message: '此音箱不支持该进度调整',
      );
    }
    // 固件 API 拼写为 positon，不能修正为 position。
    await _client.ubus(
      session,
      deviceId: device.id,
      method: 'player_set_positon',
      message: {'position': positionMs, 'media': 'app_ios'},
    );
  }

  Future<int?> volume(
    MiDirectSession session,
    MiDirectDevice device,
    int volume,
  ) async {
    final target = volume.clamp(0, 100);
    var accepted = false;
    int? lastValue;
    final variants = [
      for (final media in [null, 'app_ios', 'common', 'app_android'])
        (
          'player_set_volume',
          <String, Object?>{
            'volume': target,
            if (media != null) 'media': media,
          },
        ),
      (
        'player_set_continuous_volume',
        <String, Object?>{'volume': target, 'media': 'app_ios'},
      ),
    ];
    for (final (method, message) in variants) {
      try {
        await _client.ubus(
          session,
          deviceId: device.id,
          method: method,
          message: message,
        );
        accepted = true;
      } on ApiFailure catch (failure) {
        if (failure.code != 'MI_DIRECT_REJECTED') rethrow;
        continue;
      }
      final state = await status(session, device);
      lastValue = MiSpeakerStatus(state).volume?.clamp(0, 100);
      if (lastValue != null && (lastValue - target).abs() <= 1) {
        return lastValue;
      }
    }
    if (!accepted) {
      throw const ApiFailure(
        kind: ApiFailureKind.server,
        code: 'MI_DIRECT_VOLUME_REJECTED',
        message: '音箱未接受音量调整',
      );
    }
    return lastValue;
  }
}
