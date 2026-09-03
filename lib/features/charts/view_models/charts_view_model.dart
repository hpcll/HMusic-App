import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/models/hmusic_track.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/queue/api_queue_repository.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../../search/data/api_search_repository.dart';
import '../../settings/data/api_downloads_repository.dart';
import '../../settings/models/download_record.dart';
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

  // 入库状态轮询：有排队/下载中的条目时每 3s 拉一次 /downloads，全部落地自动
  // 停表（同「本地下载」子页的纪律）。服务端不报百分比，所以只轮状态。
  static const Duration _archivePollInterval = Duration(seconds: 3);
  Timer? _archivePoll;

  @override
  ChartsViewState build() {
    ref.onDispose(_stopArchivePoll);
    return const ChartsViewState();
  }

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
      // 入库索引只在进详情时拉一次：行上要标「已入库/下载中」，但不值得为它
      // 常驻轮询（服务端只报状态不报进度，完整列表在设置的「本地下载」）。
      unawaited(_loadDownloadIndex());
    } on ApiFailure catch (failure) {
      // 详情拉取失败退回卡片墙并提示。
      state = state.copyWith(
        clearActive: true,
        detailLoading: false,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  Future<void> _loadDownloadIndex() async {
    try {
      final records = await ref.read(downloadsRepositoryProvider).list();
      final index = <String, DownloadStatus>{};
      for (final record in records) {
        final track = record.track;
        if (track == null) continue;
        index['${track.source}:${track.sourceTrackId}'] = record.status;
      }
      state = state.copyWith(downloads: index);
      _syncArchivePoll();
    } catch (_) {
      // 索引是锦上添花：拉不到（没连服务端、旧服务端、网络抖）就当都没入库，
      // 下载按钮照样能点——服务端对同一 trackKey 是幂等的。
    }
  }

  // 有活跃条目才开表，落地即停：用户停在榜单页也能看到行从菊花变成对勾
  // （此前只在进详情时拉一次，下完不刷新，得退出重进才看得到）。
  void _syncArchivePoll() {
    final active = state.downloads.values.any(
      (status) =>
          status == DownloadStatus.pending ||
          status == DownloadStatus.downloading,
    );
    if (!active) {
      _stopArchivePoll();
      return;
    }
    _archivePoll ??= Timer.periodic(
      _archivePollInterval,
      (_) => unawaited(_loadDownloadIndex()),
    );
  }

  void _stopArchivePoll() {
    _archivePoll?.cancel();
    _archivePoll = null;
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
      state = state.copyWith(
        downloads: <String, DownloadStatus>{
          ...state.downloads,
          '${track.source}:${track.sourceTrackId}': DownloadStatus.pending,
        },
        notice: HMusicNotice.success('已开始下载：${entry.title}'),
      );
      // 立刻开表：接下来每 3s 拉一次状态，下完这一行自己变成对勾。
      _syncArchivePoll();
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    } on Exception catch (error) {
      state = state.copyWith(notice: HMusicNotice.error('$error'));
    } finally {
      state = state.copyWith(actingRank: 0);
    }
  }

  void back() {
    _stopArchivePoll();
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
