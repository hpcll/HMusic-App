import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../core/queue/models/hmusic_queue.dart';
import '../../../shared/widgets/hmusic_icon_button.dart';
import '../../../shared/widgets/hmusic_track_row.dart';

// 队列曲目行：复用全站曲目行原子（对齐 .queue-current 语义）。
// 当前曲序号位换青绿均衡器图标、标题转青绿（青绿=「正在发生的事」，同榜单行）；
// 分隔线由外层 ListView.separated 提供，这里关掉自带的。
class QueueTrackTile extends StatelessWidget {
  const QueueTrackTile({
    required this.item,
    required this.index,
    required this.isCurrent,
    required this.isBusy,
    required this.onPlay,
    required this.onRemove,
    super.key,
  });

  final HMusicQueueItem item;
  final int index;
  final bool isCurrent;
  final bool isBusy;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final track = item.track;
    return HMusicTrackRow(
      // 16 对齐页头基线：外层 ListView 无水平 padding，序号左缘直接压线。
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: SizedBox(
        width: 28,
        child: Align(
          alignment: Alignment.centerLeft,
          child: isCurrent
              ? Icon(Icons.graphic_eq_rounded, size: 18, color: palette.accent)
              : Text(
                  '${index + 1}',
                  style: TextStyle(fontSize: 12.5, color: palette.muted),
                ),
        ),
      ),
      coverUrl: track.coverUrl,
      title: track.title,
      subtitle: track.artist,
      highlight: isCurrent,
      showDivider: false,
      onTap: isBusy ? null : onPlay,
      actions: <Widget>[
        if (isBusy)
          const SizedBox.square(
            dimension: 34,
            child: Center(
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          HMusicIconButton(
            icon: Icons.play_arrow_rounded,
            tooltip: '播放',
            onPressed: onPlay,
          ),
        HMusicIconButton(
          icon: Icons.close_rounded,
          tooltip: '移除',
          onPressed: isBusy ? null : onRemove,
        ),
      ],
    );
  }
}
