import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/infrastructure_providers.dart';
import '../../core/session/session_providers.dart';
import '../../shared/widgets/brand_mark.dart';
import '../theme/hmusic_palette.dart';

// 窄屏顶栏，对齐 web .topbar：品牌（衬线 HMusic）+ 退出登录。
// 退出 = 清 token + 会话失效，由 app_router 的 redirect 统一回登录页。
class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(color: palette.background),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Padding(
            // 16 对齐全页内容基线（页头/列表/dock 同列），品牌不再独自缩进 18。
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const BrandMark(size: 20),
                    const SizedBox(width: 9),
                    Text(
                      'HMusic',
                      style: TextStyle(
                        fontFamily: 'NotoSerifSC',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: palette.textStrong,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _logout(ref),
                  child: const Text('退出'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout(WidgetRef ref) async {
    await ref.read(tokenStoreProvider).clear();
    ref.read(sessionControllerProvider).invalidate();
  }
}
