import '../../../core/queue/models/hmusic_queue.dart';

enum QueueStatus { idle, loading, loaded }

class QueueViewState {
  const QueueViewState({
    this.status = QueueStatus.idle,
    this.queue,
    this.busyItemId,
    this.errorMessage,
  });

  final QueueStatus status;
  final HMusicQueue? queue;
  final String? busyItemId;
  final String? errorMessage;

  bool get isLoading => status == QueueStatus.loading;

  List<HMusicQueueItem> get items => queue?.items ?? const <HMusicQueueItem>[];

  int get currentIndex => queue?.currentIndex ?? -1;

  QueueViewState copyWith({
    QueueStatus? status,
    HMusicQueue? queue,
    String? busyItemId,
    String? errorMessage,
    bool clearBusyItem = false,
    bool clearError = false,
  }) {
    return QueueViewState(
      status: status ?? this.status,
      queue: queue ?? this.queue,
      busyItemId: clearBusyItem ? null : busyItemId ?? this.busyItemId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
