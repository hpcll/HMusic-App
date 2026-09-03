import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/downloads/download_index.dart';
import '../../../core/models/hmusic_track.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/queue/api_queue_repository.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../../search/data/api_search_repository.dart';
import '../../settings/data/api_downloads_repository.dart';
import '../data/api_charts_repository.dart';
import '../models/chart.dart';
import '../models/charts_view_state.dart';

// 榜单条目的入库键：与服务端 downloads.trackKey 同口径（source:sourceTrackId）。
// 无 track 快照的条目（Apple 榜）拿不到键——它们的曲目要点了才由搜索匹配出来，
// 所以索引里不会有它们，行上一律显示可下载。
String? chartEntryTrackKey(ChartEntry entry) {
  final track = entry.track;
  if (track == null) return null;
  return '${track.source}:${track.sourceTrackId}';
}

final NotifierProvider<ChartsViewModel, ChartsViewState>
chartsViewModelProvider = NotifierProvider<ChartsViewModel, ChartsViewState>(
  ChartsViewModel.new,
);

class ChartsViewModel extends Notifier<ChartsViewState> {
  // 预取代数：reload 时自增，丢弃旧代回填的预览，避免竞态。
  int _generation = 0;

  @override
  ChartsViewState build() => const ChartsViewState();

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(status: ChartsStatus.loading, clearError: true);
    final List<Chart> charts;
    try {
      charts = await ref.read(chartsRepositoryProvider).getCharts();
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        status: ChartsStatus.error,
        errorMessage: failure.message,
      );
      return;
    }
    state = state.copyWith(
      status: ChartsStatus.loaded,
      charts: charts,
      previews: const <String, List<ChartEntry>?>{},
    );
    _prefetchPreviews(charts, generation);
  }

  // 并发预取各榜前 3 首做卡片预览，顺带焐热后端 6h 缓存（进详情秒开），对齐 web。
  void _prefetchPreviews(List<Chart> charts, int generation) {
    for (final chart in charts) {
      unawaited(
        ref
            .read(chartsRepositoryProvider)
            .getChart(chart.id)
            .then((detail) {
              if (generation != _generation) return;
              _writePreview(chart.id, detail.entries.take(3).toList());
            })
            .catchError((Object _) {
              if (generation != _generation) return;
              _writePreview(chart.id, null);
            }),
      );
    }
  }

  void _writePreview(String id, List<ChartEntry>? top) {
    state = state.copyWith(
      previews: <String, List<ChartEntry>?>{...state.previews, id: top},
    );
  }

  Future<void> openChart(Chart summary) async {
    state = state.copyWith(
      active: summary,
      clearDetail: true,
      detailLoading: true,
      clearError: true,
    );
    try {
      final detail = await ref
          .read(chartsRepositoryProvider)
          .getChart(summary.id);
      state = state.copyWith(detail: detail, detailLoading: false);
      // 行上要标「已入库/下载中」：索引与轮询由共享的 downloadIndex 负责
      //（搜索结果页用同一份，见 core/downloads/download_index.dart）。
      unawaited(ref.read(downloadIndexProvider.notifier).refresh());
    } on ApiFailure catch (failure) {
      // 详情拉取失败退回卡片墙并提示。
      state = state.copyWith(
        clearActive: true,
        detailLoading: false,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  // 下载到服务器曲库（对齐搜索页的「下载到服务器」）：不选音质，按服务端默认
  // 下——榜单是一眼十几行的场景，多一次弹窗不值。发起后乐观标成排队中，真实
  // 进度在设置的「本地下载」页。
  Future<void> download(ChartEntry entry) async {
    if (state.actingRank != 0) return;
    state = state.copyWith(actingRank: entry.rank, clearError: true);
    try {
      final track = await _resolveEntry(entry);
      await ref.read(downloadsRepositoryProvider).start(track);
      // 乐观标排队中 + 开表：下完这一行自己变成对勾，不用退出重进。
      ref.read(downloadIndexProvider.notifier).markQueued(track);
      state = state.copyWith(
        notice: HMusicNotice.success('已开始下载：${entry.title}'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    } on Exception catch (error) {
      state = state.copyWith(notice: HMusicNotice.error('$error'));
    } finally {
      state = state.copyWith(actingRank: 0);
    }
  }

  void back() {
    ref.read(downloadIndexProvider.notifier).stop();
    state = state.copyWith(clearActive: true, clearDetail: true);
  }

  Future<void> play(ChartEntry entry) async {
    if (state.actingRank != 0) return;
    state = state.copyWith(actingRank: entry.rank, clearError: true);
    try {
      final track = await _resolveEntry(entry);
      final handler = await ref.read(hmusicAudioHandlerProvider.future);
      await handler.playTrack(track);
      state = state.copyWith(
        notice: HMusicNotice.success('正在播放：${entry.title}'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    } on Exception catch (error) {
      state = state.copyWith(notice: HMusicNotice.error('$error'));
    } finally {
      state = state.copyWith(actingRank: 0);
    }
  }

  Future<void> enqueue(ChartEntry entry) async {
    if (state.actingRank != 0) return;
    state = state.copyWith(actingRank: entry.rank, clearError: true);
    try {
      final track = await _resolveEntry(entry);
      await ref.read(queueRepositoryProvider).addTrack(track);
      state = state.copyWith(
        notice: HMusicNotice.success('已加入队列：${entry.title}'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    } on Exception catch (error) {
      state = state.copyWith(notice: HMusicNotice.error('$error'));
    } finally {
      state = state.copyWith(actingRank: 0);
    }
  }

  // 整榜播放：服务端整榜灌队列开播，返回的权威状态立即喂给 AudioHandler
  // 在本机装载出声，不等前台轮询。
  Future<void> playAll() async {
    final active = state.active;
    if (active == null || state.actingRank != 0) return;
    state = state.copyWith(actingRank: -1, clearError: true);
    try {
      final playback = await ref
          .read(chartsRepositoryProvider)
          .playAll(active.id);
      final handler = await ref.read(hmusicAudioHandlerProvider.future);
      await handler.applyRemotePlayback(playback);
      state = state.copyWith(
        notice: HMusicNotice.success('整榜播放：${active.name}'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    } on Exception catch (error) {
      state = state.copyWith(notice: HMusicNotice.error('$error'));
    } finally {
      state = state.copyWith(actingRank: 0);
    }
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }

  // 榜单条目 → 可播曲目：带快照直接用；否则搜「歌名 歌手」取第一条（Apple 榜）。
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
