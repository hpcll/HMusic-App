import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'method_channel_platform_shell_bridge.dart';
import 'platform_shell_bridge.dart';

// iOS 由 Swift/SwiftUI NativeGlassShell 承载 chrome；Android/桌面用 Flutter 回退壳，
// 不发原生 intent、不回报 inset。P0 阶段 NoOpBridge 让 PlatformShellController 的
// 调用全部成为安全空操作，避免非 iOS 平台因缺通道而报错。
class NoOpPlatformShellBridge implements PlatformShellBridge {
  @override
  Stream<ShellLayout> get layoutChanges => const Stream<ShellLayout>.empty();

  @override
  Stream<ShellIntentType> get intents => const Stream<ShellIntentType>.empty();

  @override
  Future<void> configure({
    required bool darkMode,
    required bool reduceMotion,
    required bool reduceTransparency,
  }) async {}

  @override
  Future<void> updateNavigation({
    required String selectedTab,
    required String title,
    required bool canGoBack,
  }) async {}
}

// 按平台选择 chrome 桥：iOS 走 MethodChannel 到 NativeGlassShell，其余平台用空桥。
// 用 Provider 而非全局函数，便于测试注入伪造桥。
final Provider<PlatformShellBridge> platformShellBridgeProvider =
    Provider<PlatformShellBridge>((ref) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return MethodChannelPlatformShellBridge();
      }
      return NoOpPlatformShellBridge();
    });
