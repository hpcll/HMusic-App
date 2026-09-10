import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/models/hmusic_playback_state.dart';
import '../network/api_failure.dart';

// 客户端音频后端能力，与 Server 的设备在线状态、内容能力分开。
// Windows/Linux 继续通过既有 AudioHandler 遥控，不能把无后端解释成不能连接。
class ClientPlaybackCapabilities {
  const ClientPlaybackCapabilities({required this.supportsLocalPlayback});

  factory ClientPlaybackCapabilities.forPlatform(TargetPlatform platform) =>
      ClientPlaybackCapabilities(
        supportsLocalPlayback: switch (platform) {
          TargetPlatform.android ||
          TargetPlatform.iOS ||
          TargetPlatform.macOS => true,
          _ => false,
        },
      );

  final bool supportsLocalPlayback;

  static const String localPlaybackUnavailableReason = '此平台暂不支持本机播放，请选择音箱';

  bool canSelectDevice({required String deviceId, String? deviceType}) =>
      supportsLocalPlayback ||
      (deviceId != HMusicPlaybackState.localDeviceId &&
          deviceType != 'browser');

  bool canControl(HMusicPlaybackState state) =>
      supportsLocalPlayback || !state.isLocalDevice;

  void requireLocalPlayback() {
    if (supportsLocalPlayback) return;
    throw const ApiFailure(
      kind: ApiFailureKind.invalidConfiguration,
      code: 'LOCAL_PLAYBACK_UNAVAILABLE',
      message: localPlaybackUnavailableReason,
    );
  }
}

final Provider<ClientPlaybackCapabilities> clientPlaybackCapabilitiesProvider =
    Provider<ClientPlaybackCapabilities>(
      (_) => ClientPlaybackCapabilities.forPlatform(defaultTargetPlatform),
    );
