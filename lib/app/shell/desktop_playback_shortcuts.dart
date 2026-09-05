import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/hmusic_audio_handler.dart';
import '../../features/player/view_models/player_view_model.dart';

// 桌面键盘快捷键：空格 播放/暂停，←/→ seek ∓/±10s，⌘/Ctrl+←/→ 上一首/下一首。
// 挂在 MaterialApp.builder（Navigator 之上）：push 出去的播放页与弹层同样生效。
// 移动平台无实体键盘，原样返回 child。焦点在文本框时按键归输入框（EditableText
// 自身先消费，这里再兜一层判断）；连发节流防长按 KeyRepeat 刷指令（远端音箱
// 走服务端命令串行化，仍不该被键盘灌爆）。命令统一走 PlayerViewModel，与
// 页面按钮/系统媒体键同一条链路，失败自动转全局 toast。
class DesktopPlaybackShortcuts extends ConsumerStatefulWidget {
  const DesktopPlaybackShortcuts({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DesktopPlaybackShortcuts> createState() =>
      _DesktopPlaybackShortcutsState();
}

enum _PlayerCommand { toggle, seekBack, seekForward, next, previous }

class _PlayerCommandIntent extends Intent {
  const _PlayerCommandIntent(this.command);

  final _PlayerCommand command;
}

class _DesktopPlaybackShortcutsState
    extends ConsumerState<DesktopPlaybackShortcuts> {
  static const Set<TargetPlatform> _desktop = <TargetPlatform>{
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  };

  // 硬件键盘 repeat ~30/s：250ms 折算 4 次/s，跟手又不刷屏。
  static const Duration _throttle = Duration(milliseconds: 250);

  DateTime _lastFire = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Widget build(BuildContext context) {
    if (!_desktop.contains(Theme.of(context).platform)) return widget.child;
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.space):
            const _PlayerCommandIntent(_PlayerCommand.toggle),
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            const _PlayerCommandIntent(_PlayerCommand.seekBack),
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            const _PlayerCommandIntent(_PlayerCommand.seekForward),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true):
            const _PlayerCommandIntent(_PlayerCommand.previous),
        const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true):
            const _PlayerCommandIntent(_PlayerCommand.next),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
            const _PlayerCommandIntent(_PlayerCommand.previous),
        const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
            const _PlayerCommandIntent(_PlayerCommand.next),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _PlayerCommandIntent: CallbackAction<_PlayerCommandIntent>(
            onInvoke: _invoke,
          ),
        },
        child: widget.child,
      ),
    );
  }

  void _invoke(_PlayerCommandIntent intent) {
    final now = DateTime.now();
    if (now.difference(_lastFire) < _throttle) return;
    _lastFire = now;

    // 焦点在文本输入里时按键必须归输入框（搜索框的空格是打字不是播控）。
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null &&
        focusContext.findAncestorStateOfType<EditableTextState>() != null) {
      return;
    }

    final controller = ref.read(playerViewModelProvider);
    switch (intent.command) {
      case _PlayerCommand.toggle:
        final handler = ref.read(hmusicAudioHandlerProvider).value;
        if (handler == null) return;
        if (handler.player.playing) {
          unawaited(controller.pause());
        } else {
          unawaited(controller.play());
        }
      case _PlayerCommand.seekBack:
      case _PlayerCommand.seekForward:
        final handler = ref.read(hmusicAudioHandlerProvider).value;
        if (handler == null) return;
        final delta = intent.command == _PlayerCommand.seekForward
            ? const Duration(seconds: 10)
            : const Duration(seconds: -10);
        unawaited(controller.seek(handler.effectivePosition + delta));
      case _PlayerCommand.next:
        unawaited(controller.skipToNext());
      case _PlayerCommand.previous:
        unawaited(controller.skipToPrevious());
    }
  }
}
