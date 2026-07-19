import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../../../core/session/session_providers.dart';

// 窄屏设置菜单底部的退出登录行：App 无常驻顶栏后（对齐 Apple Music），
// 退出的唯一窄屏入口移到这里；桌面仍走侧栏底部按钮。
// 退出 = 清 token + 会话失效，由 app_router 的 redirect 统一回登录页
//（与 AppSidebar._logout 同一条链路）。
class SettingsLogoutRow extends ConsumerWidget {
  const SettingsLogoutRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Center(
        child: TextButton.icon(
          onPressed: () async {
            await ref.read(tokenStoreProvider).clear();
            ref.read(sessionControllerProvider).invalidate();
          },
          icon: const Icon(Icons.logout_rounded, size: 16),
          label: const Text('退出登录'),
          style: TextButton.styleFrom(foregroundColor: context.palette.muted),
        ),
      ),
    );
  }
}
