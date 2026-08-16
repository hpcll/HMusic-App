import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/queue/api_queue_repository.dart';
import 'package:hmusic/features/queue/views/queue_page.dart';

import 'support/fake_queue_repository.dart';

Widget _app(FakeQueueRepository repository) => ProviderScope(
  overrides: [queueRepositoryProvider.overrideWithValue(repository)],
  child: const MaterialApp(home: QueuePage()),
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
}
