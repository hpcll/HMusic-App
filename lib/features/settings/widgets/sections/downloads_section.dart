import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../core/audio/models/hmusic_playback_state.dart';
import '../../../../shared/widgets/hmusic_card.dart';
import '../../../../shared/widgets/hmusic_icon_button.dart';
import '../../../../shared/widgets/state_dot.dart';
import '../../models/download_record.dart';
import '../../view_models/auto_archive_view_model.dart';
import '../../view_models/downloads_view_model.dart';

// 本地下载子页：说明 + 已下载/下载中列表（状态点 + 大小 + 失败原因）。
// 失败可重试，任意条目可删本地文件。进行中由 VM 每 3s 轮询。对齐 web DownloadsSection。
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
        Text(
          '下载到服务器本地的歌播放时直接走本地文件——不再依赖平台直链，永不过期。'
          '搜索结果和榜单行的下载图标都能加入。',
          style: TextStyle(fontSize: 12, color: palette.muted, height: 1.6),
        ),
        const SizedBox(height: 14),
        const _AutoArchiveRow(),
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
                  _DownloadRow(
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

// 自动入库开关：默认关。开着时任何页面点播的在线歌都会顺手下一份到服务器，
// 听过的歌自然积累成本地曲库；关着就只有手动点下载图标才下。
class _AutoArchiveRow extends ConsumerWidget {
  const _AutoArchiveRow();

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
                  '听过就下一份到服务器，下次免解析；服务器硬盘会随之变大。',
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

// 下载记录行：状态点 + 标题 + 「状态 · 大小 · 歌手（失败原因）」+ 重试/删除。
class _DownloadRow extends StatelessWidget {
  const _DownloadRow({
    required this.record,
    required this.showDivider,
    required this.busy,
    required this.onRetry,
    required this.onRemove,
  });

  final DownloadRecord record;
  final bool showDivider;
  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: palette.lineSoft))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    record.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: palette.textStrong,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      StateDot(_dotStatus(record.status), size: 7),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _subtitle(record),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: palette.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (record.status == DownloadStatus.failed)
              HMusicIconButton(
                icon: Icons.refresh_rounded,
                tooltip: '重试',
                onPressed: busy ? null : onRetry,
              ),
            HMusicIconButton(
              icon: Icons.close_rounded,
              tooltip: '删除本地文件',
              onPressed: busy ? null : onRemove,
            ),
          ],
        ),
      ),
    );
  }

  // 完成=青绿（成品在库），失败=danger，排队/下载中=paused 黄。
  PlaybackStatus _dotStatus(DownloadStatus status) {
    return switch (status) {
      DownloadStatus.done => PlaybackStatus.playing,
      DownloadStatus.failed => PlaybackStatus.error,
      _ => PlaybackStatus.paused,
    };
  }

  String _subtitle(DownloadRecord record) {
    final label = switch (record.status) {
      DownloadStatus.pending => '排队中',
      DownloadStatus.downloading => '下载中…',
      DownloadStatus.done => '已下载',
      DownloadStatus.failed => '失败',
      DownloadStatus.unknown => '未知',
    };
    final size = _sizeLabel(record.byteSize);
    final artist = record.artist ?? '未知';
    final reason =
        record.status == DownloadStatus.failed && record.error != null
        ? '（${record.error}）'
        : '';
    return '$label$size · $artist$reason';
  }

  String _sizeLabel(int? bytes) {
    if (bytes == null || bytes == 0) return '';
    final mb = bytes / 1024 / 1024;
    return mb >= 1
        ? ' · ${mb.toStringAsFixed(1)} MB'
        : ' · ${(bytes / 1024).round()} KB';
  }
}
