import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/downloads/download_index.dart';
import '../../../core/models/hmusic_track.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/queue/api_queue_repository.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../../settings/data/api_downloads_repository.dart';
import '../data/api_search_repository.dart';
import '../models/search_view_state.dart';

final NotifierProvider<SearchViewModel, SearchViewState>
searchViewModelProvider = NotifierProvider<SearchViewModel, SearchViewState>(
  SearchViewModel.new,
);

class SearchViewModel extends Notifier<SearchViewState> {
  int _requestId = 0;

  @override
  SearchViewState build() => const SearchViewState();

  Future<void> play(HMusicTrack track) async {
    if (state.playingTrackId != null) return;
    state = state.copyWith(playingTrackId: track.id, clearError: true);
    try {
      final handler = await ref.read(hmusicAudioHandlerProvider.future);
      await handler.playTrack(track);
    } on ApiFailure catch (failure) {
      state = state.copyWith(errorMessage: failure.message);
    } on Exception catch (error) {
      state = state.copyWith(errorMessage: '播放失败：$error');
    } finally {
      state = state.copyWith(clearPlayingTrack: true);
    }
  }

  Future<void> enqueue(HMusicTrack track) async {
    try {
      await ref.read(queueRepositoryProvider).addTrack(track);
      state = state.copyWith(
        notice: HMusicNotice.success('已加入队列：${track.title}'),
        clearError: true,
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(errorMessage: failure.message);
    }
  }

  // 下载到服务器本地（对齐 web「下载到服务器」）：下载后这首歌播放走本地文件、
  // 免直链过期。quality 省略时服务端按默认音质下。发起是尽力而为，进度在设置
  // 下载管理页看，这里只报「已开始」。
  Future<void> download(HMusicTrack track, {String? quality}) async {
    try {
      await ref
          .read(downloadsRepositoryProvider)
          .start(track, quality: quality);
      // 乐观标排队中 + 开表：下完这一行自己变成对勾（榜单页同源索引）。
      ref.read(downloadIndexProvider.notifier).markQueued(track);
      state = state.copyWith(
        notice: HMusicNotice.success('已开始下载：${track.title}'),
        clearError: true,
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(errorMessage: failure.message);
    }
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }

  Future<void> search(String input) async {
    final query = input.trim();
    if (query.isEmpty || state.isSearching) return;
    final requestId = ++_requestId;
    state = state.copyWith(
      status: SearchStatus.searching,
      query: query,
      clearError: true,
    );
    try {
      final result = await ref.read(searchRepositoryProvider).search(query);
      if (requestId != _requestId) return;
      state = state.copyWith(
        status: SearchStatus.loaded,
        tracks: result.tracks,
        clearError: true,
      );
      // 出结果就拉一次入库索引：行尾要标「已入库/下载中」（与榜单页同一份）。
      unawaited(ref.read(downloadIndexProvider.notifier).refresh());
    } on ApiFailure catch (failure) {
      if (requestId != _requestId) return;
      state = state.copyWith(
        status: SearchStatus.loaded,
        tracks: const [],
        errorMessage: failure.message,
      );
    }
  }
}
