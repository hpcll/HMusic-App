import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/hmusic_audio_handler.dart';
import 'session_controller.dart';

final Provider<SessionController> sessionControllerProvider =
    Provider<SessionController>((ref) {
      final controller = SessionController();
      ref.onDispose(controller.dispose);
      return controller;
    });

// 把 401 单飞接到停止本机音频：第一次失效时停播放器，
// 后续重复 401 由 SessionController 自身去重，不再重复 stop。
// 不在这里跳路由——路由跳转由 refreshListenable 在 app_router 统一处理，
// 避免 ViewModel 监听器里持有 BuildContext。
final Provider<void> sessionGuardProvider = Provider<void>((ref) {
  final controller = ref.watch(sessionControllerProvider);
  controller.addListener(() {
    if (!controller.isInvalid) return;
    unawaited(
      ref
          .read(hmusicAudioHandlerProvider.future)
          .then((handler) => handler.stop())
          .catchError((Object _) {}),
    );
  });
});
