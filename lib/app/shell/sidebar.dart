import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/infrastructure_providers.dart';
import '../../core/session/session_providers.dart';
import '../theme/hmusic_palette.dart';
import 'bottom_nav.dart' show kSidebarDestinations;

// 桌面固定侧栏（结构版），对齐 web .sidebar：232 宽 / 右侧细边 / 品牌 + 7 导航 + 底部退出。
// 7 项顺序与 web 一致：正在播放/搜索/队列/歌单/榜单/统计/设置（播放与队列即桌面 tab）。
// side-now 迷你播放态与用户名细节留到「桌面侧栏精修」任务补齐（移动端优先）。
class AppSidebar extends ConsumerWidget {
  const AppSidebar({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return Container(
      width: 232,
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(right: BorderSide(color: palette.line)),
      ),
      // 顶部 56：品牌行基线对齐内容区页面大标题基线——大标题顶 = 28（外壳
      // 标题栏余量）+ 24（根页统一顶距），按 NotoSerifSC 度量反推品牌顶距 ≈ 56。
      // 同时继续让出 macOS 红绿灯悬浮区（fullSizeContentView 下叠在侧栏左上）。
      // 改任一根页顶距或大标题字号时需同步复核这里。
      padding: const EdgeInsets.fromLTRB(22, 56, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 26),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.graphic_eq_rounded,
                  size: 24,
                  color: palette.textStrong,
                ),
                const SizedBox(width: 10),
                Text(
                  'HMusic',
                  style: TextStyle(
                    fontFamily: 'NotoSerifSC',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: palette.textStrong,
                  ),
                ),
              ],
            ),
          ),
          for (final spec in kSidebarDestinations)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _SideItem(
                icon: spec.icon,
                label: spec.label,
                active: shell.currentIndex == spec.branch,
                onTap: () => shell.goBranch(
                  spec.branch,
                  initialLocation: spec.branch == shell.currentIndex,
                ),
              ),
            ),
          const Spacer(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _logout(ref),
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('退出登录'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(WidgetRef ref) async {
    await ref.read(tokenStoreProvider).clear();
    ref.read(sessionControllerProvider).invalidate();
  }
}

// 侧栏导航项：hover 底→panel-2；active 墨底反白（bg 字 on text-strong 底）。
class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = active ? palette.background : palette.mutedStrong;
    return Material(
      color: active ? palette.textStrong : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 11),
              Text(label, style: TextStyle(fontSize: 14, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
