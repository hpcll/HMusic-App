import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/network/api_failure.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../data/api_playlists_repository.dart';
import '../models/playlist.dart';
import '../models/playlists_view_state.dart';

final NotifierProvider<PlaylistsViewModel, PlaylistsViewState>
playlistsViewModelProvider =
    NotifierProvider<PlaylistsViewModel, PlaylistsViewState>(
      PlaylistsViewModel.new,
    );

class PlaylistsViewModel extends Notifier<PlaylistsViewState> {
  @override
  PlaylistsViewState build() => const PlaylistsViewState();

  Future<void> loadList() async {
    state = state.copyWith(status: PlaylistsStatus.loading, clearError: true);
    try {
      final playlists = await ref
          .read(playlistsRepositoryProvider)
          .getPlaylists();
      state = state.copyWith(
        status: PlaylistsStatus.loaded,
        playlists: playlists,
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        status: PlaylistsStatus.error,
        errorMessage: failure.message,
      );
    }
  }

  Future<void> openPlaylist(String id) async {
    state = state.copyWith(detailLoading: true, clearError: true);
    try {
      final detail = await ref
          .read(playlistsRepositoryProvider)
          .getPlaylist(id);
      state = state.copyWith(detail: detail, detailLoading: false);
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        detailLoading: false,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  // 返回列表并刷新（曲目数可能因移除而变化）。
  Future<void> backToList() async {
    state = state.copyWith(clearDetail: true);
    await loadList();
  }

  Future<void> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await ref.read(playlistsRepositoryProvider).createPlaylist(trimmed);
      await _reloadKeepingBusy();
      state = state.copyWith(
        busy: false,
        notice: const HMusicNotice.success('歌单已创建'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        busy: false,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  Future<void> import(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty || state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final result = await ref
          .read(playlistsRepositoryProvider)
          .importPlaylist(trimmed);
      await _reloadKeepingBusy();
      state = state.copyWith(
        busy: false,
        notice: HMusicNotice.success(_importMessage(result)),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        busy: false,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  Future<void> deletePlaylist(String id) async {
    if (state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await ref.read(playlistsRepositoryProvider).deletePlaylist(id);
      await _reloadKeepingBusy();
      state = state.copyWith(
        busy: false,
        notice: const HMusicNotice.success('歌单已删除'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        busy: false,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  Future<void> removeItem(String itemId) async {
    final detail = state.detail;
    if (detail == null || state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final updated = await ref
          .read(playlistsRepositoryProvider)
          .removeItem(detail.id, itemId);
      state = state.copyWith(busy: false, detail: updated);
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        busy: false,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  // 整单播放：服务端整单灌队列并从 startIndex 开播，返回的权威状态立即喂给
  // AudioHandler 在本机装载出声（just_audio 无需手势解锁），不等前台轮询。
  Future<void> playAll(String id, {int startIndex = 0}) async {
    if (state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final playback = await ref
          .read(playlistsRepositoryProvider)
          .playAll(id, startIndex: startIndex);
      final handler = await ref.read(hmusicAudioHandlerProvider.future);
      await handler.applyRemotePlayback(playback);
      state = state.copyWith(
        busy: false,
        notice: const HMusicNotice.success('开始播放歌单'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        busy: false,
        notice: HMusicNotice.error(failure.message),
      );
    } on Exception catch (error) {
      // 本机装载失败（如直链坏源）也要如实提示，而不是谎报“开始播放”。
      state = state.copyWith(busy: false, notice: HMusicNotice.error('$error'));
    }
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }

  Future<void> _reloadKeepingBusy() async {
    try {
      final playlists = await ref
          .read(playlistsRepositoryProvider)
          .getPlaylists();
      state = state.copyWith(
        status: PlaylistsStatus.loaded,
        playlists: playlists,
      );
    } on ApiFailure {
      // 刷新失败不覆盖主操作的成功提示；下次进页再拉。
    }
  }

  String _importMessage(PlaylistImportResult result) {
    final buffer = StringBuffer('《${result.name}》已导入 ${result.imported} 首');
    if (result.skipTotal > 0) {
      final parts = <String>[
        if (result.skipDuplicate > 0) '去重 ${result.skipDuplicate}',
        if (result.skipTruncated > 0) '超上限截断 ${result.skipTruncated}',
        if (result.skipEmptyTitle > 0) '无效 ${result.skipEmptyTitle}',
      ];
      buffer.write('（跳过 ${parts.join('、')}）');
    }
    return buffer.toString();
  }
}
