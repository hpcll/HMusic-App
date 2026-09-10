import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../shared/widgets/hmusic_card.dart';
import '../../view_models/auto_archive_view_model.dart';

// 自动入库开关：默认关。开着时任何页面点播的在线歌都会顺手下一份到服务器，
// 听过的歌自然积累成本地曲库；关着就只有手动点下载图标才下。
class AutoArchiveOption extends ConsumerWidget {
  const AutoArchiveOption({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final enabled = ref.watch(autoArchiveEnabledProvider);
    return HMusicCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '播放过的在线歌自动入库',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: palette.textStrong,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '播放时自动保存到服务器，会占用服务器磁盘空间。',
                  style: TextStyle(fontSize: 12.5, color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: enabled,
            onChanged: (value) => unawaited(
              ref.read(autoArchiveEnabledProvider.notifier).setEnabled(value),
            ),
          ),
        ],
      ),
    );
  }
}
