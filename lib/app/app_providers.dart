import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/audio/hmusic_audio_handler.dart';
import '../core/platform_shell/platform_shell_controller.dart';
import '../core/platform_shell/platform_shell_providers.dart';
import '../features/player/view_models/player_view_model.dart';
import 'router/app_router.dart';

// 用 Provider 持有 GoRouter，使 SessionController 的 refreshListenable 能跨重建复用，
// 且 buildAppRouter 可在测试中注入 Ref override。
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  final router = buildAppRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});

// mini player 是否有曲目（播放/暂停均算）：桌面壳据此决定内容区是否为悬浮
// mini 让出底部 inset——无曲目时 mini 自身塌缩，inset 不能占位。
final StreamProvider<bool> miniPlayerActiveProvider = StreamProvider<bool>((
  ref,
) async* {
  final handler = await ref.watch(hmusicAudioHandlerProvider.future);
  yield* handler.mediaItem.map((item) => item != null).distinct();
});

// 平台壳控制器：订阅原生 intent 并派发到路由/播放器；路由与播放状态变化时
// 下发 chrome 展示状态。仅 iOS 经 MethodChannel 与 NativeGlassShell 双向通信；
// 其余平台用 NoOp 桥安全空操作。audio handler 异步就绪后接入 nowPlaying 推送。
final Provider<PlatformShellController> platformShellControllerProvider =
    Provider<PlatformShellController>((ref) {
      final controller = PlatformShellController(
        bridge: ref.watch(platformShellBridgeProvider),
        router: ref.watch(appRouterProvider),
        playerViewModel: ref.watch(playerViewModelProvider),
      );
      ref.listen(
        hmusicAudioHandlerProvider,
        (_, handler) => handler.whenData(controller.attachAudioHandler),
        fireImmediately: true,
      );
      ref.onDispose(controller.dispose);
      return controller;
    });
