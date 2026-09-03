import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/api_downloads_repository.dart';
import '../../features/settings/models/download_record.dart';
import '../models/hmusic_track.dart';

// 「这首歌在服务器曲库里了吗」的共享索引：键为 trackKey（source:sourceTrackId），
// 值为服务端下载记录的状态。榜单行与搜索结果行都靠它决定行尾那一格画什么
// （↓ / 菊花 / 灰对勾），两页共用一份，切页不用重新猜。
//
// 有排队/下载中的条目时每 3s 拉一次 /downloads，全部落地自动停表——服务端只报
// 状态不报百分比，所以轮的是状态；完整列表和删除/重试在设置的「本地下载」页。
final NotifierProvider<DownloadIndex, Map<String, DownloadStatus>>
downloadIndexProvider =
    NotifierProvider<DownloadIndex, Map<String, DownloadStatus>>(
      DownloadIndex.new,
    );

String downloadKeyOf(HMusicTrack track) =>
    '${track.source}:${track.sourceTrackId}';

class DownloadIndex extends Notifier<Map<String, DownloadStatus>> {
  static const Duration _pollInterval = Duration(seconds: 3);
  Timer? _poll;

  @override
  Map<String, DownloadStatus> build() {
    ref.onDispose(stop);
    return const <String, DownloadStatus>{};
  }

  bool isArchived(HMusicTrack? track) =>
      track != null && state[downloadKeyOf(track)] == DownloadStatus.done;

  bool isArchiving(HMusicTrack? track) {
    if (track == null) return false;
    final status = state[downloadKeyOf(track)];
    return status == DownloadStatus.pending ||
        status == DownloadStatus.downloading;
  }

  // 拉一次服务端记录重建索引。失败静默：索引是锦上添花，拉不到就当都没入库，
  // 下载按钮照样能点（服务端对同一 trackKey 幂等）。
  Future<void> refresh() async {
    try {
      final records = await ref.read(downloadsRepositoryProvider).list();
      final next = <String, DownloadStatus>{};
      for (final record in records) {
        final track = record.track;
        if (track == null) continue;
        next[downloadKeyOf(track)] = record.status;
      }
      state = next;
      _syncPoll();
    } catch (_) {
      // 见上：静默。
    }
  }

  // 刚点下下载：先乐观标成排队中（行立刻转菊花），随后由轮询接管真实状态。
  void markQueued(HMusicTrack track) {
    state = <String, DownloadStatus>{
      ...state,
      downloadKeyOf(track): DownloadStatus.pending,
    };
    _syncPoll();
  }

  void _syncPoll() {
    final active = state.values.any(
      (status) =>
          status == DownloadStatus.pending ||
          status == DownloadStatus.downloading,
    );
    if (!active) {
      stop();
      return;
    }
    _poll ??= Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
  }

  // 离开用到索引的页面时停表（回来会再 refresh 一次）。
  void stop() {
    _poll?.cancel();
    _poll = null;
  }
}
