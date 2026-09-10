import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../shared/widgets/hmusic_card.dart';
import '../../../../shared/widgets/hmusic_inline_notice.dart';
import '../../view_models/downloads_view_model.dart';
import 'auto_archive_option.dart';
import 'download_record_row.dart';

// 服务器下载子页：说明 + 已下载/下载中列表；进行中由 VM 每 3s 轮询。
class DownloadsSectionView extends ConsumerStatefulWidget {
  const DownloadsSectionView({super.key});

  @override
  ConsumerState<DownloadsSectionView> createState() =>
      _DownloadsSectionViewState();
}

class _DownloadsSectionViewState extends ConsumerState<DownloadsSectionView> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(downloadsViewModelProvider.notifier).load(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = ref.watch(downloadsViewModelProvider);
    final notifier = ref.read(downloadsViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 就地反馈：本节操作的结果/错误显示在顶部，不弹浮层。
        if (state.notice != null) ...<Widget>[
          HMusicInlineNotice(state.notice!),
          const SizedBox(height: 12),
        ],
        Text(
          '音频保存到已连接的服务器，完成后加入 NAS 曲库。播放时需要连接服务器。'
          '搜索结果和榜单中的下载图标都能添加。',
          style: TextStyle(fontSize: 12, color: palette.muted, height: 1.6),
        ),
        const SizedBox(height: 14),
        const AutoArchiveOption(),
        const SizedBox(height: 16),
        if (!state.loaded)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Center(
              child: Text('加载中…', style: TextStyle(color: palette.muted)),
            ),
          )
        else if (state.items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Center(
              child: Text('还没有下载的音乐', style: TextStyle(color: palette.muted)),
            ),
          )
        else
          HMusicCard(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var i = 0; i < state.items.length; i++)
                  DownloadRecordRow(
                    record: state.items[i],
                    showDivider: i != state.items.length - 1,
                    busy: state.actingId.isNotEmpty,
                    onRetry: () => notifier.retry(state.items[i]),
                    onRemove: () => notifier.remove(state.items[i]),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
