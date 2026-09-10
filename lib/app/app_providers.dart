import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/audio/hmusic_audio_handler.dart';
import '../core/audio/playback_projection.dart';
import '../core/platform_shell/platform_shell_controller.dart';
import '../core/platform_shell/platform_shell_providers.dart';
import '../features/player/models/playback_output_label.dart';
import '../features/player/view_models/player_view_model.dart';
import 'router/app_router.dart';

// 用 Provider 持有 GoRouter，使 SessionController 的 refreshListenable 能跨重建复用，
// 且 buildAppRouter 可在测试中注入 Ref override。
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  final router = buildAppRouter(ref);
  ref.onDispose(router.dispose);
  return router;
});

// 与手机/桌面播放条共用 Server 曲目判定，冷启动恢复态也为已显示的条保留空间。
final Provider<bool> miniPlayerActiveProvider = Provider<bool>(
  (ref) => ref.watch(
    serverPlaybackStateProvider.select((state) => state.value?.track != null),
  ),
);

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
      ref.listen(serverPlaybackStateProvider, (_, state) {
        if (state.hasValue) {
          final track = state.value?.track;
          controller.updateMetadata(
            track: track == null ? null : mediaItemForTrack(track),
            outputLabel: playbackOutputLabel(state.value),
          );
        }
      }, fireImmediately: true);
      ref.onDispose(controller.dispose);
      return controller;
    });
