import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../app/theme/hmusic_radii.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../../../core/session/session_providers.dart';
import '../../connection/views/connection_page.dart';

// 窄屏设置菜单底部的账户操作卡片（桌面走侧栏，不渲染此卡）：显示当前服务器
// 地址 + 更换服务器（次要操作，文本按钮弱化）+ 退出登录（危险操作，outlined
// 红色按钮视觉差异化）——信息层级清晰、符合 10 年 UI 原则的账户区块化设计。
class SettingsAccountCard extends ConsumerWidget {
  const SettingsAccountCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final store = ref.watch(serverConfigStoreProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: FutureBuilder<Uri?>(
        future: store.read(),
        builder: (context, snapshot) {
          final serverBase = snapshot.data?.toString() ?? '未连接';
          return Material(
            color: palette.panel,
            borderRadius: BorderRadius.circular(HMusicRadii.card),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: palette.line),
                borderRadius: BorderRadius.circular(HMusicRadii.card),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // 账户区块标题
                  Text(
                    '账户',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: palette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // 当前服务器信息（只读，文字样式弱化）
                  Text(
                    '当前服务器',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.mutedStrong,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    serverBase,
                    style: TextStyle(fontSize: 13.5, color: palette.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 18),
                  // 按钮行：更换服务器（左对齐，次要操作）+ 退出登录（右对齐，危险操作）
                  Row(
                    children: <Widget>[
                      // 更换服务器：文本按钮 + muted 灰弱化（次要操作）
                      TextButton.icon(
                        onPressed: () => context.go(ConnectionPage.path),
                        icon: const Icon(Icons.lan_rounded, size: 16),
                        label: const Text('更换服务器'),
                        style: TextButton.styleFrom(
                          foregroundColor: palette.muted,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // 退出登录：outlined 样式 + danger 红色（危险操作视觉强化）
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ref.read(tokenStoreProvider).clear();
                          ref.read(sessionControllerProvider).invalidate();
                        },
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: const Text('退出登录'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.danger,
                          side: BorderSide(color: palette.danger),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
