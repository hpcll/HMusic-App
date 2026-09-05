import 'package:flutter/material.dart';

import '../../../shared/widgets/hmusic_dialog.dart';

// 清空整个队列不可恢复：与删歌单同一确认语言（危险色主按钮），防页头误触一键全没。
Future<bool> confirmClearQueue(BuildContext context) {
  return showHMusicDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('清空队列'),
      content: const Text('确定清空整个播放队列吗？清空后无法恢复。'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('清空'),
        ),
      ],
    ),
  ).then((ok) => ok ?? false);
}
