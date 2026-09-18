import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/build_edition.dart';
import '../network/api_failure.dart';
import '../platform/client_playback_capabilities.dart';
import '../providers/infrastructure_providers.dart';
import 'playback_mode.dart';
import 'playback_mode_store.dart';

final playbackModeStoreProvider = Provider<PlaybackModeStore>(
  (ref) => PlaybackModeStore(preferences: ref.watch(keyValueStoreProvider)),
);

final playbackModeProvider =
    NotifierProvider<PlaybackModeController, PlaybackMode>(
      PlaybackModeController.new,
    );

class PlaybackModeController extends Notifier<PlaybackMode> {
  Future<PlaybackMode>? _restoring;
  int _generation = 0;

  int get generation => _generation;

  @override
  PlaybackMode build() => PlaybackMode.server;

  Future<PlaybackMode> restore() async {
    try {
      await (_restoring ??= _restore());
      return state;
    } catch (_) {
      _restoring = null;
      rethrow;
    }
  }

  Future<PlaybackMode> _restore() async {
    final saved = await ref.read(playbackModeStoreProvider).read();
    if (ref.mounted) {
      final unsupportedPlayer =
          saved == PlaybackMode.player &&
          !ref.read(clientPlaybackCapabilitiesProvider).supportsLocalPlayback;
      final mode = BuildEdition.isStore || unsupportedPlayer
          ? PlaybackMode.server
          : saved;
      if (mode != state) _generation++;
      state = mode;
    }
    return state;
  }

  /// 切换事务开始前检查能力，避免目标不可用时先暂停当前播放。
  void requireSupported(PlaybackMode mode) {
    if (BuildEdition.isStore && mode.usesLocalBackend) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '此版本使用服务器模式',
      );
    }
    if (mode == PlaybackMode.player) {
      ref.read(clientPlaybackCapabilitiesProvider).requireLocalPlayback();
    }
  }

  /// 调用者先停旧后端及释放资源，再提交模式，失败时保留原来的活动模式。
  Future<void> select(PlaybackMode mode) async {
    requireSupported(mode);
    await restore();
    if (state == mode) return;
    await ref.read(playbackModeStoreProvider).write(mode);
    _generation++;
    state = mode;
  }
}
