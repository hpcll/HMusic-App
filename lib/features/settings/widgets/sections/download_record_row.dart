import 'package:flutter/material.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../core/audio/models/hmusic_playback_state.dart';
import '../../../../shared/widgets/hmusic_icon_button.dart';
import '../../../../shared/widgets/state_dot.dart';
import '../../models/download_record.dart';

// 下载记录行：状态点 + 标题 + 「状态 · 大小 · 歌手（失败原因）」+ 重试/删除。
class DownloadRecordRow extends StatelessWidget {
  const DownloadRecordRow({
    required this.record,
    required this.showDivider,
    required this.busy,
    required this.onRetry,
    required this.onRemove,
    super.key,
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
              tooltip: '删除服务器文件',
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
