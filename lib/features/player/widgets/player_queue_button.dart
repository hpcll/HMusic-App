import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/layout/shell_metrics.dart';
import '../../queue/views/queue_page.dart';

class PlayerQueueButton extends StatelessWidget {
  const PlayerQueueButton({required this.length, super.key});
  final int length;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 44,
    child: IconButton(
      tooltip: '播放队列（$length）',
      icon: const Icon(Icons.queue_music_rounded),
      onPressed: () {
        if (usesBottomNavigation(MediaQuery.sizeOf(context).width)) {
          unawaited(context.push(QueuePage.path));
        } else {
          context.go(QueuePage.tabPath);
        }
      },
    ),
  );
}
