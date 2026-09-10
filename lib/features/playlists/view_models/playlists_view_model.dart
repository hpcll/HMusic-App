import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/playback/backend_request.dart';
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
  PlaylistsViewState build() {
    ref.watch(playlistsRepositoryProvider);
    return const PlaylistsViewState();
  }

  Future<void> loadList() async {
    final request = BackendRequest(ref);
    state = state.copyWith(status: PlaylistsStatus.loading, clearError: true);
    try {
      final playlists = await ref
          .read(playlistsRepositoryProvider)
          .getPlaylists();
      if (!request.current) return;
      state = state.copyWith(
        status: PlaylistsStatus.loaded,
        playlists: playlists,
      );
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(
        status: PlaylistsStatus.error,
        errorMessage: failure.message,
      );
    }
  }

  Future<void> openPlaylist(String id) async {
    final request = BackendRequest(ref);
    state = state.copyWith(detailLoading: true, clearError: true);
    try {
      final detail = await ref
          .read(playlistsRepositoryProvider)
          .getPlaylist(id);
      if (!request.current) return;
      state = state.copyWith(detail: detail, detailLoading: false);
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(
        detailLoading: false,
        errorMessage: failure.message,
      );
    }
  }

  // 返回列表并刷新（曲目数可能因移除而变化）。
  Future<void> backToList() async {
    state = state.copyWith(clearDetail: true);
    await loadList();
  }

  Future<void> create(String name) async {
    final request = BackendRequest(ref);
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await ref.read(playlistsRepositoryProvider).createPlaylist(trimmed);
      if (!request.current) return;
      await _reloadKeepingBusy();
      if (!request.current) return;
      state = state.copyWith(busy: false);
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(busy: false, errorMessage: failure.message);
    }
  }

  Future<void> import(String url) async {
    final request = BackendRequest(ref);
    final trimmed = url.trim();
    if (trimmed.isEmpty || state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final result = await ref
          .read(playlistsRepositoryProvider)
          .importPlaylist(trimmed);
      if (!request.current) return;
      await _reloadKeepingBusy();
      if (!request.current) return;
      state = state.copyWith(
        busy: false,
        notice: HMusicNotice.success(_importMessage(result)),
      );
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(busy: false, errorMessage: failure.message);
    }
  }

  Future<void> deletePlaylist(String id) async {
    final request = BackendRequest(ref);
    if (state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await ref.read(playlistsRepositoryProvider).deletePlaylist(id);
      if (!request.current) return;
      await _reloadKeepingBusy();
      if (!request.current) return;
      state = state.copyWith(busy: false);
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(busy: false, errorMessage: failure.message);
    }
  }

  // 返回是否成功，供行左滑删除决定走移除动画还是回弹。
  Future<bool> removeItem(String itemId) async {
    final request = BackendRequest(ref);
    final detail = state.detail;
    if (detail == null || state.busy) return false;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final updated = await ref
          .read(playlistsRepositoryProvider)
          .removeItem(detail.id, itemId);
      if (!request.current) return false;
      state = state.copyWith(busy: false, detail: updated);
      return true;
    } on ApiFailure catch (failure) {
      if (!request.current) return false;
      state = state.copyWith(busy: false, errorMessage: failure.message);
      return false;
    }
  }

  // 整单播放：服务端整单灌队列并从 startIndex 开播，返回的权威状态立即喂给
  // AudioHandler 在本机装载出声（just_audio 无需手势解锁），不等前台轮询。
  Future<void> playAll(String id, {int startIndex = 0}) async {
    final request = BackendRequest(ref);
    if (state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      final repository = ref.read(playlistsRepositoryProvider);
      final handler = await ref.read(hmusicAudioHandlerProvider.future);
      request.requireCurrent();
      await handler.executePlayback(() {
        request.requireCurrent();
        return repository.playAll(id, startIndex: startIndex);
      });
      if (!request.current) return;
      state = state.copyWith(busy: false);
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(busy: false, errorMessage: failure.message);
    } on Exception catch (error) {
      if (!request.current) return;
      // 本机装载失败（如直链坏源）也要如实提示，而不是静默不动。
      state = state.copyWith(busy: false, errorMessage: '$error');
    }
  }

  Future<void> _reloadKeepingBusy() async {
    final request = BackendRequest(ref);
    try {
      final playlists = await ref
          .read(playlistsRepositoryProvider)
          .getPlaylists();
      if (!request.current) return;
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
