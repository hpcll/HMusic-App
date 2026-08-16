import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/audio/models/hmusic_playback_state.dart' show PlayMode;
import '../../../core/models/hmusic_track.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/queue/api_queue_repository.dart';
import '../../../core/queue/models/hmusic_queue.dart';
import '../models/queue_view_state.dart';

final NotifierProvider<QueueViewModel, QueueViewState> queueViewModelProvider =
    NotifierProvider<QueueViewModel, QueueViewState>(QueueViewModel.new);

class QueueViewModel extends Notifier<QueueViewState> {
  @override
  QueueViewState build() => const QueueViewState();

  Future<void> load() async {
    state = state.copyWith(status: QueueStatus.loading, clearError: true);
    await _run(() => ref.read(queueRepositoryProvider).getQueue());
  }

  // 队列点播一步到位：playTrack 携带 queueIndex，服务端同步指针。
  // 禁止先 /queue/current 再 play 的两步写法（半成功窗口），见 docs/08。
  Future<void> playAt(int index) async {
    final item = _itemAt(index);
    if (item == null || state.isMutating) return;
    state = state.copyWith(busyItemId: item.id, clearError: true);
    try {
      final handler = await ref.read(hmusicAudioHandlerProvider.future);
      await handler.playTrack(item.track, queueIndex: index);
    } on ApiFailure catch (failure) {
      state = state.copyWith(errorMessage: failure.message);
    } finally {
      state = state.copyWith(clearBusyItem: true);
      // 无论成败都与服务端对齐，杜绝指针错位。
      await _run(() => ref.read(queueRepositoryProvider).getQueue());
    }
  }

  // 无单曲删除接口：整体替换为去掉该曲后的列表，指针按删除位相应前移。
  // 返回是否成功，供左滑删除决定走移除动画还是回弹。
  Future<bool> removeAt(int index) {
    final queue = state.queue;
    if (queue == null || _itemAt(index) == null || state.isMutating) {
      return Future<bool>.value(false);
    }
    final remaining = <HMusicTrack>[
      for (var i = 0; i < queue.items.length; i++)
        if (i != index) queue.items[i].track,
    ];
    final current = queue.currentIndex;
    final nextCurrent = index < current
        ? current - 1
        : current >= remaining.length
        ? remaining.length - 1
        : current;
    return _mutate(
      () => ref
          .read(queueRepositoryProvider)
          .replaceQueue(
            tracks: remaining,
            currentIndex: nextCurrent < 0 ? 0 : nextCurrent,
            playMode: queue.playMode,
          ),
    );
  }

  Future<void> changeMode(PlayMode mode) {
    return _mutate(() => ref.read(queueRepositoryProvider).setPlayMode(mode));
  }

  Future<void> clear() {
    return _mutate(() => ref.read(queueRepositoryProvider).clear());
  }

  HMusicQueueItem? _itemAt(int index) {
    final items = state.items;
    if (index < 0 || index >= items.length) return null;
    return items[index];
  }

  // 写操作统一互斥：任意写（点播/删除/清空/换模式）进行中即拒绝新写，
  // 避免 replaceQueue 与 mode/clear 交错落地造成指针或模式错位。
  Future<bool> _mutate(Future<HMusicQueue> Function() action) async {
    if (state.isMutating) return false;
    state = state.copyWith(mutating: true);
    try {
      return await _run(action);
    } finally {
      state = state.copyWith(mutating: false);
    }
  }

  Future<bool> _run(Future<HMusicQueue> Function() action) async {
    try {
      final queue = await action();
      state = state.copyWith(
        status: QueueStatus.loaded,
        queue: queue,
        clearError: true,
      );
      return true;
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        status: QueueStatus.loaded,
        errorMessage: failure.message,
      );
      return false;
    }
  }
}
