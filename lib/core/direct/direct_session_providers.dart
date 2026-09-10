import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/hmusic_audio_handler.dart';
import '../playback/playback_mode.dart';
import '../playback/playback_mode_controller.dart';
import '../session/session_controller.dart';
import 'direct_providers.dart';
import 'mi_direct_providers.dart';
import 'mi_direct_session.dart';

final directSessionControllerProvider = Provider<SessionController>((ref) {
  final controller = SessionController();
  ref.onDispose(controller.dispose);
  return controller;
});

final directSessionGuardProvider = Provider<void>((ref) {
  final account = ref.watch(miDirectAccountRepositoryProvider);
  final session = ref.watch(directSessionControllerProvider);
  Future<void> expire(MiDirectSession rejected) async {
    if (!await account.expire(rejected) || !ref.mounted) return;
    session.invalidate();
    if (ref.read(playbackModeProvider) != PlaybackMode.direct) return;
    if (ref.exists(hmusicAudioHandlerProvider)) {
      try {
        await (await ref.read(hmusicAudioHandlerProvider.future)).resetSession(
          stillInvalid: () =>
              ref.mounted &&
              session.isInvalid &&
              ref.read(playbackModeProvider) == PlaybackMode.direct,
        );
      } catch (_) {
        // 路由仍须退出失效账号；音频初始化失败不阻止会话清理。
      }
    }
    if (!ref.mounted ||
        !session.isInvalid ||
        ref.read(playbackModeProvider) != PlaybackMode.direct) {
      return;
    }
    if (ref.exists(directPlaybackRepositoryProvider)) {
      await ref.read(directPlaybackRepositoryProvider).close();
    }
  }

  final subscription = ref
      .watch(miMinaClientProvider)
      .expiredSessions
      .listen(
        (rejected) => unawaited(
          expire(rejected).catchError((Object _) {
            // 安全存储失败留待下次校验重试，不能清理可能已经更新的账号。
          }),
        ),
        onError: (Object _) {},
      );
  ref.onDispose(() => unawaited(subscription.cancel()));
});
