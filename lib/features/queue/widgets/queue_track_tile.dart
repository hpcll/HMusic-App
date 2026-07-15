import 'package:flutter/material.dart';

import '../../../core/queue/models/hmusic_queue.dart';

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
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final track = item.track;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: SizedBox(
        width: 28,
        child: Center(
          child: isCurrent
              ? Icon(Icons.music_note, size: 18, color: accent)
              : Text('${index + 1}', style: theme.textTheme.bodySmall),
        ),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isCurrent
            ? theme.textTheme.titleMedium?.copyWith(color: accent)
            : theme.textTheme.titleMedium,
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: isBusy ? null : onPlay,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: '播放',
            onPressed: isBusy ? null : onPlay,
            icon: isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
          ),
          IconButton(
            tooltip: '移除',
            onPressed: isBusy ? null : onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
