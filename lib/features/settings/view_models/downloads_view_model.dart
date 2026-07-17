import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../data/api_downloads_repository.dart';
import '../models/download_record.dart';
import '../models/downloads_state.dart';

final NotifierProvider<DownloadsViewModel, DownloadsState>
downloadsViewModelProvider =
    NotifierProvider<DownloadsViewModel, DownloadsState>(
      DownloadsViewModel.new,
    );

// 本地下载（对齐 web DownloadsSection）：列表 + 删除 + 重试。
// 有排队/下载中记录时每 3s 轮询，全部结束自动停表；轮询开关跟子页生命周期。
class DownloadsViewModel extends Notifier<DownloadsState> {
  Timer? _timer;

  @override
  DownloadsState build() {
    ref.onDispose(_stop);
    return const DownloadsState();
  }

  Future<void> load() async {
    try {
      final items = await ref.read(downloadsRepositoryProvider).list();
      state = state.copyWith(items: items, loaded: true);
      _syncPolling();
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        loaded: true,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  Future<void> remove(DownloadRecord item) async {
    if (state.actingId.isNotEmpty) return;
    state = state.copyWith(actingId: item.id);
    try {
      await ref.read(downloadsRepositoryProvider).remove(item.id);
      await load();
      state = state.copyWith(notice: const HMusicNotice.success('已删除本地文件'));
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    } finally {
      state = state.copyWith(actingId: '');
    }
  }

  Future<void> retry(DownloadRecord item) async {
    final track = item.track;
    if (track == null) {
      state = state.copyWith(notice: const HMusicNotice.error('缺少曲目信息，无法重试'));
      return;
    }
    if (state.actingId.isNotEmpty) return;
    state = state.copyWith(actingId: item.id);
    try {
      await ref.read(downloadsRepositoryProvider).retry(track);
      await load();
      state = state.copyWith(
        notice: HMusicNotice.success('重新下载：${item.title}'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    } finally {
      state = state.copyWith(actingId: '');
    }
  }

  void stopPolling() => _stop();

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }

  // 有活跃下载才开表，无则停；load 后调用，随下载完成自动收敛。
  void _syncPolling() {
    if (state.hasActive) {
      _timer ??= Timer.periodic(
        const Duration(seconds: 3),
        (_) => unawaited(load()),
      );
    } else {
      _stop();
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }
}
