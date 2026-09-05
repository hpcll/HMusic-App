import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../search/views/search_page.dart';

// 队列空态：文案 + 行动按钮（去搜索），不再是只说不给路的死胡同提示。
class QueueEmptyState extends StatelessWidget {
  const QueueEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('队列是空的'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.push(SearchPage.path),
          icon: const Icon(Icons.search_rounded, size: 18),
          label: const Text('去搜索加几首歌'),
        ),
      ],
    );
  }
}
