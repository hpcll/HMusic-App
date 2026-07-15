import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/network/api_failure.dart';
import '../data/api_stats_repository.dart';
import '../models/stats.dart';
import '../models/stats_view_state.dart';

final NotifierProvider<StatsViewModel, StatsViewState> statsViewModelProvider =
    NotifierProvider<StatsViewModel, StatsViewState>(StatsViewModel.new);

class StatsViewModel extends Notifier<StatsViewState> {
  @override
  StatsViewState build() => const StatsViewState();

  Future<void> load() async {
    state = state.copyWith(status: StatsStatus.loading, clearError: true);
    try {
      final stats = await ref.read(statsRepositoryProvider).getStats();
      state = state.copyWith(status: StatsStatus.loaded, stats: stats);
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        status: StatsStatus.error,
        errorMessage: failure.message,
      );
    }
  }

  // Top 歌行点播：带历史快照直接走播放管线。
  Future<void> play(TrackStat item) async {
    final track = item.track;
    if (track == null) {
      state = state.copyWith(notice: '这首缺少可播放信息');
      return;
    }
    if (state.actingKey.isNotEmpty) return;
    state = state.copyWith(actingKey: item.key, clearError: true);
    try {
      final handler = await ref.read(hmusicAudioHandlerProvider.future);
      await handler.playTrack(track);
      state = state.copyWith(notice: '正在播放：${item.title}');
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: failure.message);
    } on Exception catch (error) {
      state = state.copyWith(notice: '$error');
    } finally {
      state = state.copyWith(actingKey: '');
    }
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }
}
