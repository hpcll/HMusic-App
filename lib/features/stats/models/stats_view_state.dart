import 'stats.dart';

enum StatsStatus { initial, loading, loaded, error }

// 统计页状态：单次聚合 + Top 歌点播防连点。
class StatsViewState {
  const StatsViewState({
    this.status = StatsStatus.initial,
    this.stats,
    this.actingKey = '',
    this.errorMessage,
    this.notice,
  });

  final StatsStatus status;
  final Stats? stats;

  // 正在点播的 Top 歌 key（title+artist），防连点。
  final String actingKey;
  final String? errorMessage;
  final String? notice;

  StatsViewState copyWith({
    StatsStatus? status,
    Stats? stats,
    String? actingKey,
    String? errorMessage,
    String? notice,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return StatsViewState(
      status: status ?? this.status,
      stats: stats ?? this.stats,
      actingKey: actingKey ?? this.actingKey,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}
