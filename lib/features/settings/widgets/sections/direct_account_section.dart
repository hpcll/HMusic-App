import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../core/playback/playback_mode_switch.dart';
import '../../../../shared/models/hmusic_notice.dart';
import '../../../../shared/widgets/hmusic_inline_notice.dart';
import '../../view_models/settings_menu_view_model.dart';
import '../settings_form_card.dart';

class DirectAccountSection extends ConsumerWidget {
  const DirectAccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(settingsMenuViewModelProvider);
    final state = ref.watch(playbackModeSwitchProvider);
    return SettingsFormCard(
      title: '小米账号',
      description: '用于连接你的小爱音箱，登录凭据保存在此设备。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            menu.summary.mi.isEmpty ? '正在读取账号…' : menu.summary.mi,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: context.palette.textStrong,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '当前播放设备：${menu.summary.devices.isEmpty ? '未选择' : menu.summary.devices}',
          ),
          const SizedBox(height: 24),
          if (state.error != null) ...[
            HMusicInlineNotice(HMusicNotice.error(state.error!)),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: state.busy
                ? null
                : ref.read(playbackModeSwitchProvider.notifier).logoutDirect,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(state.busy ? '正在退出…' : '退出小米账号'),
          ),
          const SizedBox(height: 10),
          Text(
            '退出会停止播放并清除小米凭据，保留本机歌单、音源与听歌记录。',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: context.palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}
