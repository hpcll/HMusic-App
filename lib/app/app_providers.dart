import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

// 平台壳控制器：订阅原生 intent 并派发到路由/播放器。
// 仅在 iOS 经 MethodChannel 与 NativeGlassShell 双向通信；其余平台用 NoOp 桥安全空操作。
final Provider<PlatformShellController> platformShellControllerProvider =
    Provider<PlatformShellController>((ref) {
      final controller = PlatformShellController(
        bridge: ref.watch(platformShellBridgeProvider),
        router: ref.watch(appRouterProvider),
        playerViewModel: ref.watch(playerViewModelProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });
