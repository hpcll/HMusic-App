import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform_shell/widgets/adaptive_glass_surface.dart';
import '../../features/settings/models/settings_section.dart';
import '../../features/settings/view_models/mi_session_watch_view_model.dart';
import '../../features/settings/view_models/settings_menu_view_model.dart';
import '../../features/settings/views/settings_page.dart';
import '../theme/hmusic_palette.dart';

// 小米会话过期的常驻横幅：悬浮于内容区顶部（临时浮层，可用玻璃），点按深链
// 设置 → 小米账号，× 本次运行内不再提示。挂载与回前台各触发一次限频真校验，
// 过期状态由 miSessionWatchProvider 供给（播放报错回读、设置页登录/退出同步）。
class MiSessionBanner extends ConsumerStatefulWidget {
  const MiSessionBanner({super.key});

  @override
  ConsumerState<MiSessionBanner> createState() => _MiSessionBannerState();
}

class _MiSessionBannerState extends ConsumerState<MiSessionBanner> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _check);
    unawaited(Future<void>.microtask(_check));
  }

  void _check() {
    unawaited(ref.read(miSessionWatchProvider.notifier).check());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final show = ref.watch(miSessionWatchProvider.select((s) => s.showBanner));
    // 出现/消失走 mini player 同款节奏（docs/03 §4：220ms easeOut）。
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      child: show ? const _BannerCapsule() : const SizedBox.shrink(),
    );
  }
}

// 玻璃胶囊横幅：⚠ 危险色图标 + 墨色文案 + muted 关闭键，无 hairline
//（Apple Music 语言）。整体可点，关闭键单独截获。
class _BannerCapsule extends ConsumerWidget {
  const _BannerCapsule();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return AdaptiveGlassSurface(
      quality: resolveGlassQuality(context),
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(19),
      hairline: false,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            ref
                .read(settingsMenuViewModelProvider.notifier)
                .open(SettingsSection.mi);
            context.go(SettingsPage.path);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: palette.danger,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    '小米账号登录已过期，点按重新登录',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: palette.textStrong,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      ref.read(miSessionWatchProvider.notifier).dismiss(),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: palette.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
