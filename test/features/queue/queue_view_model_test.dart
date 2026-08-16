import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart'
    show PlayMode;
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/queue/api_queue_repository.dart';
import 'package:hmusic/features/queue/view_models/queue_view_model.dart';

import 'support/fake_queue_repository.dart';

ProviderContainer _container(FakeQueueRepository repository) {
  final container = ProviderContainer(
    overrides: [queueRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('removeAt 删除当前曲之前的条目：指针前移一位', () async {
    final repository = FakeQueueRepository(queue: buildQueue(currentIndex: 2));
    final container = _container(repository);
    final viewModel = container.read(queueViewModelProvider.notifier);
    await viewModel.load();

    final ok = await viewModel.removeAt(0);

    expect(ok, isTrue);
    expect(repository.calls, contains('replace:2:1'));
  });

  test('removeAt 删除当前曲之后的条目：指针不动', () async {
    final repository = FakeQueueRepository(queue: buildQueue());
    final container = _container(repository);
    final viewModel = container.read(queueViewModelProvider.notifier);
    await viewModel.load();

    await viewModel.removeAt(2);

    expect(repository.calls, contains('replace:2:0'));
  });

  test('写操作互斥：removeAt 挂起期间 changeMode/clear/再删都被拒绝', () async {
    final repository = FakeQueueRepository(queue: buildQueue());
    final container = _container(repository);
    final viewModel = container.read(queueViewModelProvider.notifier);
    await viewModel.load();

    repository.gate = Completer<void>();
    final removing = viewModel.removeAt(0);
    expect(container.read(queueViewModelProvider).isMutating, isTrue);

    await viewModel.changeMode(PlayMode.shuffle);
    await viewModel.clear();
    final concurrentRemove = await viewModel.removeAt(1);

    expect(concurrentRemove, isFalse);
    // 只有首个 removeAt 触达仓库；互斥中的写全部在入口被拒。
    expect(repository.calls.where((call) => call != 'get'), <String>[
      'replace:2:0',
    ]);

    repository.gate!.complete();
    expect(await removing, isTrue);
    expect(container.read(queueViewModelProvider).isMutating, isFalse);

    // 互斥释放后写操作恢复可用。
    await viewModel.changeMode(PlayMode.shuffle);
    expect(repository.calls, contains('mode:shuffle'));
  });

  test('removeAt 失败：返回 false 并落 errorMessage，互斥释放', () async {
    final repository = FakeQueueRepository(queue: buildQueue());
    final container = _container(repository);
    final viewModel = container.read(queueViewModelProvider.notifier);
    await viewModel.load();

    repository.failure = const ApiFailure(
      kind: ApiFailureKind.server,
      message: '服务器开小差了',
    );
    final ok = await viewModel.removeAt(0);

    expect(ok, isFalse);
    final state = container.read(queueViewModelProvider);
    expect(state.errorMessage, '服务器开小差了');
    expect(state.isMutating, isFalse);
  });
}
