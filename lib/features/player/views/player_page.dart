import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../view_models/player_view_model.dart';
import '../widgets/player_body.dart';
import '../widgets/player_queue_button.dart';

class PlayerPage extends ConsumerWidget {
  const PlayerPage({super.key});

  // 手机 push 全屏，rail/侧栏使用原有 tab；播放状态不随布局切换重建。
  static const String path = '/player';
  static const String tabPath = '/now';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverState = ref.watch(serverPlaybackStateProvider);
    final isTab =
        GoRouter.maybeOf(context) != null &&
        GoRouterState.of(context).matchedLocation == tabPath;
    final body = SafeArea(
      child: serverState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('播放状态不可用：$error')),
        data: (state) => PlayerBody(state: state),
      ),
    );

    if (isTab) return body;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '收起播放器',
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('正在播放'),
        actions: <Widget>[
          PlayerQueueButton(length: serverState.value?.queueLength ?? 0),
        ],
      ),
      body: body,
    );
  }
}
