import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/hmusic_audio_handler.dart';
import '../direct/direct_providers.dart';
import '../direct/direct_session_providers.dart';
import '../direct/mi_direct_providers.dart';
import '../network/api_failure.dart';
import 'playback_mode.dart';
import 'playback_mode_controller.dart';

class ModeSwitchState {
  const ModeSwitchState({this.busy = false, this.error});
  final bool busy;
  final String? error;
}

final playbackModeSwitchProvider =
    NotifierProvider<PlaybackModeSwitch, ModeSwitchState>(
      PlaybackModeSwitch.new,
    );

class PlaybackModeSwitch extends Notifier<ModeSwitchState> {
  @override
  ModeSwitchState build() => const ModeSwitchState();

  Future<bool> select(PlaybackMode target) => _run(() async {
    final controller = ref.read(playbackModeProvider.notifier);
    controller.requireSupported(target);
    final previous = await controller.restore();
    if (previous == target) return;
    await _transition((controlled) async {
      if (previous.usesLocalBackend) {
        await _closeDirect(
          preservePosition: true,
          controlPlayback: !controlled,
        );
      }
      await controller.select(target);
    }, preservePosition: true);
  });

  Future<bool> logoutDirect() => _run(() async {
    await _transition((controlled) async {
      await _closeDirect(controlPlayback: !controlled);
      await ref.read(miDirectAccountRepositoryProvider).logout();
      ref.read(directSessionControllerProvider).invalidate();
    });
  });

  Future<void> _transition(
    Future<void> Function(bool controlled) commit, {
    bool preservePosition = false,
  }) async {
    // 首次连接页无需为了切模式初始化系统媒体服务；已在初始化则等待同一个实例。
    if (ref.exists(hmusicAudioHandlerProvider)) {
      final handler = await ref.read(hmusicAudioHandlerProvider.future);
      await handler.transitionBackend(
        () => commit(handler.serverState?.track != null),
        preservePosition: preservePosition,
      );
    } else {
      await commit(false);
    }
  }

  Future<void> _closeDirect({
    bool preservePosition = false,
    bool controlPlayback = true,
  }) async {
    if (ref.exists(directPlaybackRepositoryProvider)) {
      final playback = ref.read(directPlaybackRepositoryProvider);
      // 未初始化 Handler 的直连目标也要暂停；模式切换保留位置，退出账号才停止。
      if (controlPlayback) {
        if (preservePosition) {
          await playback.pause();
        } else {
          await playback.stop();
        }
      }
      await playback.close();
    }
    if (ref.exists(directLxSourcesProvider)) {
      ref.read(directLxSourcesProvider).close();
    }
    if (ref.exists(directAudioProxyProvider)) {
      await ref.read(directAudioProxyProvider).close();
    }
    if (ref.read(playbackModeProvider) == PlaybackMode.direct) {
      await ref.read(miDirectAccountRepositoryProvider).cancelLogin();
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (state.busy) return false;
    state = const ModeSwitchState(busy: true);
    try {
      await action();
      if (ref.mounted) state = const ModeSwitchState();
      return true;
    } catch (error) {
      if (ref.mounted) {
        state = ModeSwitchState(
          error: error is ApiFailure ? error.message : '切换未完成，请重试',
        );
      }
      return false;
    }
  }
}
