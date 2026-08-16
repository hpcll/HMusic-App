import '../../../core/queue/models/hmusic_queue.dart';

enum QueueStatus { idle, loading, loaded }

class QueueViewState {
  const QueueViewState({
    this.status = QueueStatus.idle,
    this.queue,
    this.busyItemId,
    this.mutating = false,
    this.errorMessage,
  });

  final QueueStatus status;
  final HMusicQueue? queue;
  final String? busyItemId;

  // 写操作互斥标志（删除/清空/换模式）。点播另用 busyItemId 驱动行级转圈，
  // 两者合并为 isMutating 供所有写入口检查，杜绝写命令交错竞态。
  final bool mutating;
  final String? errorMessage;

  bool get isLoading => status == QueueStatus.loading;

  bool get isMutating => mutating || busyItemId != null;

  List<HMusicQueueItem> get items => queue?.items ?? const <HMusicQueueItem>[];

  int get currentIndex => queue?.currentIndex ?? -1;

  QueueViewState copyWith({
    QueueStatus? status,
    HMusicQueue? queue,
    String? busyItemId,
    bool? mutating,
    String? errorMessage,
    bool clearBusyItem = false,
    bool clearError = false,
  }) {
    return QueueViewState(
      status: status ?? this.status,
      queue: queue ?? this.queue,
      busyItemId: clearBusyItem ? null : busyItemId ?? this.busyItemId,
      mutating: mutating ?? this.mutating,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
