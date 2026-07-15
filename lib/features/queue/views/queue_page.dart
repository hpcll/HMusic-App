import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/models/hmusic_playback_state.dart' show PlayMode;
import '../models/queue_view_state.dart';
import '../view_models/queue_view_model.dart';
import '../widgets/queue_mode_tabs.dart';
import '../widgets/queue_track_tile.dart';

class QueuePage extends ConsumerStatefulWidget {
  const QueuePage({super.key});

  // 双路由：/queue 顶级 push（窄屏全屏覆盖，AppBar 带返回）；
  // /queue-tab 为桌面 shell 分支 tab（外壳侧栏常驻，无返回键）。
  static const String path = '/queue';
  static const String tabPath = '/queue-tab';

  @override
  ConsumerState<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends ConsumerState<QueuePage> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(queueViewModelProvider.notifier).load(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(queueViewModelProvider);
    final notifier = ref.read(queueViewModelProvider.notifier);
    // maybeOf 兜底：widget 测试直接挂 MaterialApp(home:) 时树里没有 GoRouter。
    final isTab =
        GoRouter.maybeOf(context) != null &&
        GoRouterState.of(context).matchedLocation == QueuePage.tabPath;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isTab,
        title: Text('播放队列 (${state.items.length})'),
        actions: <Widget>[
          if (state.items.isNotEmpty)
            TextButton(onPressed: notifier.clear, child: const Text('清空')),
        ],
      ),
      body: SafeArea(child: _body(context, state, notifier)),
    );
  }

  Widget _body(
    BuildContext context,
    QueueViewState state,
    QueueViewModel notifier,
  ) {
    if (state.isLoading && state.queue == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: QueueModeTabs(
            active: state.queue?.playMode ?? PlayMode.listLoop,
            onSelect: notifier.changeMode,
          ),
        ),
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              state.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(child: _list(context, state, notifier)),
      ],
    );
  }

  Widget _list(
    BuildContext context,
    QueueViewState state,
    QueueViewModel notifier,
  ) {
    if (state.items.isEmpty) {
      return const Center(child: Text('队列是空的，去搜索里加几首歌吧'));
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = state.items[index];
        return QueueTrackTile(
          item: item,
          index: index,
          isCurrent: index == state.currentIndex,
          isBusy: state.busyItemId == item.id,
          onPlay: () => notifier.playAt(index),
          onRemove: () => notifier.removeAt(index),
        );
      },
    );
  }
}
