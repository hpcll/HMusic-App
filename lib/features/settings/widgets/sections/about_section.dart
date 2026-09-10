import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../core/app_version.dart';
import '../../../../core/playback/playback_mode.dart';
import '../../../../core/playback/playback_mode_controller.dart';
import '../../../../shared/widgets/hmusic_card.dart';
import '../../../../shared/widgets/hmusic_dialog.dart';
import '../../../../shared/widgets/hmusic_inline_notice.dart';
import '../../models/app_update.dart';
import '../../models/update_state.dart';
import '../../view_models/app_download_view_model.dart';
import '../../view_models/update_view_model.dart';

part 'about_server_card.dart';
part 'about_app_card.dart';
part 'about_card_elements.dart';

// 关于与更新：服务端版本检查/一键升级 + App 自身新版检查。
// App 新版在 Android 直装渠道走 App 内下载 + 进度条 + 交系统安装器；
// iOS 走 App Store 链接（app-config.json 下发，未上架只给说明、不露网盘
// 入口——APK 装不上 iOS）；桌面/商店版跳各自的下载页。
class AboutSectionView extends ConsumerStatefulWidget {
  const AboutSectionView({super.key});

  @override
  ConsumerState<AboutSectionView> createState() => _AboutSectionViewState();
}

class _AboutSectionViewState extends ConsumerState<AboutSectionView> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(updateViewModelProvider.notifier).load(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateViewModelProvider);
    final notifier = ref.read(updateViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 就地反馈：本节操作的结果/错误显示在顶部，不弹浮层。
        if (state.notice != null) ...<Widget>[
          HMusicInlineNotice(state.notice!),
          const SizedBox(height: 12),
        ],
        if (ref.watch(playbackModeProvider) == PlaybackMode.server)
          _ServerCard(state: state, notifier: notifier),
        const SizedBox(height: 14),
        _AppCard(state: state, notifier: notifier),
      ],
    );
  }
}
