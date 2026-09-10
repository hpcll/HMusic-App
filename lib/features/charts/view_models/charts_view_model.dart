import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/downloads/download_index.dart';
import '../../../core/models/hmusic_track.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/playback/backend_request.dart';
import '../../../core/playback/playback_mode.dart';
import '../../../core/playback/playback_mode_controller.dart';
import '../../../core/queue/api_queue_repository.dart';
import '../../search/data/api_search_repository.dart';
import '../../settings/data/api_downloads_repository.dart';
import '../data/api_charts_repository.dart';
import '../data/chart_detail_loader.dart';
import '../models/chart.dart';
import '../models/charts_view_state.dart';

final NotifierProvider<ChartsViewModel, ChartsViewState>
chartsViewModelProvider = NotifierProvider<ChartsViewModel, ChartsViewState>(
  ChartsViewModel.new,
);

class ChartsViewModel extends Notifier<ChartsViewState> {
  // 预取代数：reload 时自增，丢弃旧代回填的预览，避免竞态。
  int _generation = 0;
  int _detailRevision = 0;
  bool _disposed = false;
  late ChartDetailLoader _loader;

  @override
  ChartsViewState build() {
    _disposed = false;
    _loader = ChartDetailLoader(ref.watch(chartsRepositoryProvider));
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      _detailRevision++;
      _loader.clear();
    });
    return const ChartsViewState();
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  Future<void> load() async {
    final generation = ++_generation;
    _detailRevision++;
    _loader.clear();
    state = state.copyWith(
      status: ChartsStatus.loading,
      clearError: true,
      clearActive: true,
      clearDetail: true,
      detailLoading: false,
    );
    final List<Chart> charts;
    try {
      charts = await ref.read(chartsRepositoryProvider).getCharts();
    } on ApiFailure catch (failure) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(
        status: ChartsStatus.error,
        errorMessage: failure.message,
      );
      return;
    }
    if (!_isCurrent(generation)) return;
    state = state.copyWith(
      status: ChartsStatus.loaded,
      charts: charts,
      previews: const <String, List<ChartEntry>?>{},
      previewErrors: const <String, String>{},
      selectedSource: charts.any((chart) => chart.kind == state.selectedSource)
          ? state.selectedSource
          : 'featured',
    );
    await _prefetchPreviews([
      ...state.personalCharts,
      ...state.discovery,
    ], generation);
  }

  // 只预取当前可见卡片（包含全部三个个人榜），最多两个请求在途。
  Future<void> _prefetchPreviews(List<Chart> charts, int generation) async {
    var cursor = 0;
    Future<void> worker() async {
      while (_isCurrent(generation) && cursor < charts.length) {
        final chart = charts[cursor++];
        if (state.previews.containsKey(chart.id)) continue;
        try {
          final detail = await _loader.read(chart.id);
          if (_isCurrent(generation)) {
            _writePreview(chart.id, detail.entries.take(3).toList());
          }
        } catch (error) {
          if (_isCurrent(generation)) {
            _writePreview(
              chart.id,
              null,
              error is ApiFailure ? error.message : '暂时无法加载，稍后重试',
            );
          }
        }
      }
    }

    await Future.wait([worker(), worker()]);
  }

  void _writePreview(String id, List<ChartEntry>? top, [String? error]) {
    final errors = {...state.previewErrors}..remove(id);
    if (error != null) errors[id] = error;
    state = state.copyWith(
      previews: <String, List<ChartEntry>?>{...state.previews, id: top},
      previewErrors: errors,
    );
  }

  Future<void> selectSource(String source) async {
    state = state.copyWith(selectedSource: source);
    await _prefetchPreviews(state.discovery, _generation);
  }

  Future<void> retryPreview(Chart chart) async {
    _loader.invalidate(chart.id);
    state = state.copyWith(
      previews: {...state.previews}..remove(chart.id),
      previewErrors: {...state.previewErrors}..remove(chart.id),
    );
    await _prefetchPreviews([chart], _generation);
  }

  Future<void> openChart(Chart summary) async {
    final revision = ++_detailRevision;
    final generation = _generation;
    state = state.copyWith(
      active: summary,
      clearDetail: true,
      detailLoading: true,
      clearError: true,
    );
    try {
      final detail = await _loader.read(summary.id);
      if (!_isCurrent(generation) || revision != _detailRevision) return;
      state = state.copyWith(detail: detail, detailLoading: false);
      _writePreview(summary.id, detail.entries.take(3).toList());
      unawaited(ref.read(downloadIndexProvider.notifier).refresh());
    } catch (error) {
      if (!_isCurrent(generation) || revision != _detailRevision) return;
      // 详情拉取失败退回卡片墙，错误就地内联在墙页头下。
      state = state.copyWith(
        clearActive: true,
        detailLoading: false,
        errorMessage: error is ApiFailure ? error.message : '榜单加载失败，请稍后重试',
      );
    }
  }

  // 服务器下载不开放到直连模式。
  Future<void> download(ChartEntry entry) async {
    if (ref.read(playbackModeProvider) != PlaybackMode.server) return;
    final request = BackendRequest(ref);
    if (state.actingRank != 0) return;
    state = state.copyWith(actingRank: entry.rank, clearError: true);
    try {
      final track = await _resolveEntry(entry);
      request.requireCurrent();
      await ref.read(downloadsRepositoryProvider).start(track);
      if (!request.current) return;
      // 乐观标排队中 + 开表：下完这一行自己变成对勾，不用退出重进。
      ref.read(downloadIndexProvider.notifier).markQueued(track);
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(errorMessage: failure.message);
    } on Exception catch (error) {
      if (!request.current) return;
      state = state.copyWith(errorMessage: '$error');
    } finally {
      if (request.current) state = state.copyWith(actingRank: 0);
    }
  }

  void back() {
    _detailRevision++;
    ref.read(downloadIndexProvider.notifier).stop();
    state = state.copyWith(
      clearActive: true,
      clearDetail: true,
      detailLoading: false,
    );
  }

  Future<void> play(ChartEntry entry) async {
    final request = BackendRequest(ref);
    if (state.actingRank != 0) return;
    state = state.copyWith(actingRank: entry.rank, clearError: true);
    try {
      final track = await _resolveEntry(entry);
      request.requireCurrent();
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
      if (request.current) state = state.copyWith(actingRank: 0);
    }
  }

  Future<bool> enqueue(ChartEntry entry) async {
    final request = BackendRequest(ref);
    if (state.actingRank != 0) return false;
    state = state.copyWith(actingRank: entry.rank, clearError: true);
    try {
      final track = await _resolveEntry(entry);
      request.requireCurrent();
      await ref.read(queueRepositoryProvider).addTrack(track);
      return request.current;
    } on ApiFailure catch (failure) {
      if (!request.current) return false;
      state = state.copyWith(errorMessage: failure.message);
      return false;
    } on Exception catch (error) {
      if (!request.current) return false;
      state = state.copyWith(errorMessage: '$error');
      return false;
    } finally {
      if (request.current) state = state.copyWith(actingRank: 0);
    }
  }

  // 整榜播放与模式切换共用 Handler 命令队列。
  Future<void> playAll() async {
    final request = BackendRequest(ref);
    final active = state.active;
    if (active == null || state.actingRank != 0) return;
    state = state.copyWith(actingRank: -1, clearError: true);
    try {
      final repository = ref.read(chartsRepositoryProvider);
      final handler = await ref.read(hmusicAudioHandlerProvider.future);
      request.requireCurrent();
      await handler.executePlayback(() {
        request.requireCurrent();
        return repository.playAll(active.id);
      });
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(errorMessage: failure.message);
    } on Exception catch (error) {
      if (!request.current) return;
      state = state.copyWith(errorMessage: '$error');
    } finally {
      if (request.current) state = state.copyWith(actingRank: 0);
    }
  }

  Future<HMusicTrack> _resolveEntry(ChartEntry entry) async {
    final track = entry.track;
    if (track != null) return track;
    final result = await ref
        .read(searchRepositoryProvider)
        .search('${entry.title} ${entry.artist}');
    final found = result.tracks.isNotEmpty ? result.tracks.first : null;
    if (found == null) {
      throw ApiFailure(
        kind: ApiFailureKind.unknown,
        message: '没找到可播放的「${entry.title}」',
      );
    }
    return found;
  }
}
