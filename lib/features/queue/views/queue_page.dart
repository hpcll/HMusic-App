import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../core/audio/models/hmusic_playback_state.dart' show PlayMode;
import '../../../shared/widgets/view_title.dart';
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

    // 桌面 tab 形态：不用 AppBar，改与其余根页一致的大标题页头
    //（顶距 24，参与侧栏品牌基线对齐），清空动作挂页头右侧。
    if (isTab) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              24 + MediaQuery.paddingOf(context).top,
              16,
              0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    const ViewTitle('播放队列'),
                    const SizedBox(width: 10),
                    Text(
                      '${state.items.length} 首',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.palette.muted,
                      ),
                    ),
                  ],
                ),
                if (state.items.isNotEmpty)
                  TextButton(
                    onPressed: state.isMutating ? null : notifier.clear,
                    child: const Text('清空'),
                  ),
              ],
            ),
          ),
          Expanded(child: _body(context, state, notifier)),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('播放队列 (${state.items.length})'),
        actions: <Widget>[
          if (state.items.isNotEmpty)
            TextButton(
              onPressed: state.isMutating ? null : notifier.clear,
              child: const Text('清空'),
            ),
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
          // 水平 16：与页头/ListTile 默认内距同列（原 12 与两者都不齐）。
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
    final Widget list;
    if (state.items.isEmpty) {
      // 空态也可下拉刷新：别的端可能刚灌了队列。撑满视口保持文案居中。
      list = LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            SizedBox(
              height: constraints.maxHeight,
              child: const Center(child: Text('队列是空的，去搜索里加几首歌吧')),
            ),
          ],
        ),
      );
    } else {
      list = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        // 底部让位：桌面悬浮 mini 之下仍可滚到最后一行（窄屏 push 形态在
        // SafeArea 内，环境 padding 为 0，只剩基础 12）。
        padding: EdgeInsets.only(
          bottom: 12 + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: state.items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = state.items[index];
          return Dismissible(
            key: ValueKey<String>('queue-${item.id}'),
            direction: DismissDirection.endToStart,
            // 成功走滑出移除动画（权威响应随即重建列表）；失败或互斥中回弹。
            confirmDismiss: (_) {
              unawaited(HapticFeedback.mediumImpact());
              return notifier.removeAt(index);
            },
            background: ColoredBox(
              color: Theme.of(context).colorScheme.error,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
              ),
            ),
            child: QueueTrackTile(
              item: item,
              index: index,
              isCurrent: index == state.currentIndex,
              isBusy: state.busyItemId == item.id,
              onPlay: () => notifier.playAt(index),
              onRemove: () => notifier.removeAt(index),
            ),
          );
        },
      );
    }
    return RefreshIndicator.adaptive(onRefresh: notifier.load, child: list);
  }
}
