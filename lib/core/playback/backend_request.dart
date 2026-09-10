import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_failure.dart';
import 'playback_mode.dart';
import 'playback_mode_controller.dart';

/// 跨 await 保留发起时的后端；切换后不得把旧结果写入新页面或发出后续控制。
class BackendRequest {
  BackendRequest(this._ref)
    : _generation = _ref.read(playbackModeProvider.notifier).generation;

  final Ref _ref;
  final int _generation;

  bool get current =>
      _ref.mounted &&
      _ref.read(playbackModeProvider.notifier).generation == _generation;

  void requireCurrent() {
    if (!current) throw changed;
  }

  static Future<void> requireServer(Ref ref) async {
    if (await ref.read(playbackModeProvider.notifier).restore() !=
        PlaybackMode.server) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        code: 'SERVER_MODE_INACTIVE',
        message: '此功能需要服务器模式',
      );
    }
  }

  static const changed = ApiFailure(
    kind: ApiFailureKind.invalidConfiguration,
    code: 'PLAYBACK_BACKEND_CHANGED',
    message: '播放模式已切换，请重新操作',
  );
}
