import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/queue/api_queue_repository.dart';
import 'package:hmusic/features/queue/views/queue_page.dart';

import 'support/fake_queue_repository.dart';

Widget _app(
  FakeQueueRepository repository, {
  EdgeInsets padding = EdgeInsets.zero,
}) => ProviderScope(
  overrides: [queueRepositoryProvider.overrideWithValue(repository)],
  child: MaterialApp(
    home: const QueuePage(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(padding: padding, viewPadding: padding),
      child: child!,
    ),
  ),
);

void main() {
  testWidgets('左滑队列行：confirmDismiss 走 removeAt，列表按权威响应重建', (tester) async {
    final repository = FakeQueueRepository(queue: buildQueue(count: 3));
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    expect(find.text('曲目0'), findsOneWidget);

    // 删除后仓库返回只剩 2 条的权威队列。
    repository.queue = buildQueue(count: 2);
    await tester.fling(find.text('曲目0'), const Offset(-400, 0), 1200);
    await tester.pumpAndSettle();

    expect(repository.calls, contains('replace:2:0'));
    expect(find.text('曲目2'), findsNothing);
  });

  testWidgets('下拉刷新：重新拉取队列', (tester) async {
    final repository = FakeQueueRepository(queue: buildQueue(count: 1));
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    repository.calls.clear();

    await tester.fling(find.text('曲目0'), const Offset(0, 320), 1000);
    await tester.pumpAndSettle();

    expect(repository.calls, contains('get'));
  });

  // 窄屏 push 形态曾用 SafeArea 吃掉手势条高度：列表视口在手势条上沿截断，
  // 底下留一条不透明底板（「播放队列底部没有沉浸」）。列表必须铺到屏幕最底，
  // 让位改由自身 padding 承担——滚到底时最后一行仍完整露在手势条上方。
  testWidgets('窄屏 push 形态：列表铺到屏幕最底，让位只走列表 padding', (tester) async {
    final repository = FakeQueueRepository(queue: buildQueue(count: 20));
    await tester.pumpWidget(
      _app(repository, padding: const EdgeInsets.only(bottom: 34)),
    );
    await tester.pumpAndSettle();

    final Finder list = find.byType(ListView).first;
    expect(
      tester.getRect(list).bottom,
      tester.getRect(find.byType(Scaffold)).bottom,
    );
    expect(
      (tester.widget(list) as ListView).padding,
      const EdgeInsets.only(bottom: 46),
    );
  });
}
