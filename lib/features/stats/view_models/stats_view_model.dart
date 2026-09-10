import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/playback/backend_request.dart';
import '../data/api_stats_repository.dart';
import '../models/stats.dart';
import '../models/stats_view_state.dart';

final NotifierProvider<StatsViewModel, StatsViewState> statsViewModelProvider =
    NotifierProvider<StatsViewModel, StatsViewState>(StatsViewModel.new);

class StatsViewModel extends Notifier<StatsViewState> {
  @override
  StatsViewState build() {
    ref.watch(statsRepositoryProvider);
    return const StatsViewState();
  }

  Future<void> load() async {
    final request = BackendRequest(ref);
    state = state.copyWith(status: StatsStatus.loading, clearError: true);
    try {
      final stats = await ref.read(statsRepositoryProvider).getStats();
      if (!request.current) return;
      state = state.copyWith(status: StatsStatus.loaded, stats: stats);
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(
        status: StatsStatus.error,
        errorMessage: failure.message,
      );
    }
  }

  // Top 歌行点播：带历史快照直接走播放管线。
  Future<void> play(TrackStat item) async {
    final request = BackendRequest(ref);
    final track = item.track;
    if (track == null) {
      state = state.copyWith(errorMessage: '这首缺少可播放信息');
      return;
    }
    if (state.actingKey.isNotEmpty) return;
    state = state.copyWith(actingKey: item.key, clearError: true);
    try {
      final handler = await ref.read(hmusicAudioHandlerProvider.future);
      request.requireCurrent();
      await handler.playTrack(track, stillCurrent: () => request.current);
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(errorMessage: failure.message);
    } on Exception catch (error) {
      if (!request.current) return;
      state = state.copyWith(errorMessage: '$error');
    } finally {
      if (request.current) state = state.copyWith(actingKey: '');
    }
  }
}
