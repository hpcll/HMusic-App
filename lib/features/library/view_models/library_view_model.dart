import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/models/hmusic_track.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/queue/api_queue_repository.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../data/api_library_repository.dart';
import '../models/library_view_state.dart';

const int _pageSize = 50;

final NotifierProvider<LibraryViewModel, LibraryViewState>
libraryViewModelProvider = NotifierProvider<LibraryViewModel, LibraryViewState>(
  LibraryViewModel.new,
);

class LibraryViewModel extends Notifier<LibraryViewState> {
  int _requestId = 0;

  @override
  LibraryViewState build() => const LibraryViewState();

  // 当前分段 + 选中组换算成列表过滤参数。
  String? get _artistFilter =>
      state.section == LibrarySection.artists ? state.activeGroup : null;

  String? get _albumFilter =>
      state.section == LibrarySection.albums ? state.activeGroup : null;

  String? get _folderFilter =>
      state.section == LibrarySection.folders ? state.activeGroup : null;

  Future<void> load({String? query}) async {
    final term = (query ?? state.query).trim();
    final requestId = ++_requestId;
    state = state.copyWith(
      status: LibraryStatus.loading,
      query: term,
      clearError: true,
    );
    try {
      final result = await ref
          .read(libraryRepositoryProvider)
          .list(
            search: term,
            artist: _artistFilter,
            album: _albumFilter,
            folder: _folderFilter,
            limit: _pageSize,
            offset: 0,
          );
      if (requestId != _requestId) return;
      state = state.copyWith(
        status: LibraryStatus.loaded,
        items: result.items,
        total: result.total,
        scan: result.scan,
      );
    } on ApiFailure catch (failure) {
      if (requestId != _requestId) return;
      state = state.copyWith(
        status: LibraryStatus.loaded,
        errorMessage: failure.message,
      );
    }
  }

  // 切分段：全部→拉曲目；歌手/专辑→拉聚合列表（组选择清空）。
  Future<void> setSection(LibrarySection section) async {
    if (state.section == section) return;
    state = state.copyWith(
      section: section,
      clearActiveGroup: true,
      clearError: true,
    );
    if (section == LibrarySection.all) {
      await load();
    } else {
      await loadGroups();
    }
  }

  Future<void> loadGroups() async {
    final section = state.section;
    if (section == LibrarySection.all) return;
    state = state.copyWith(groupsLoading: true, clearError: true);
    try {
      final groups = await ref.read(libraryRepositoryProvider).groups(
        switch (section) {
          LibrarySection.artists => 'artist',
          LibrarySection.albums => 'album',
          _ => 'folder',
        },
      );
      if (state.section != section) return; // 期间又切走了，丢弃。
      state = state.copyWith(groups: groups, groupsLoading: false);
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        groupsLoading: false,
        errorMessage: failure.message,
      );
    }
  }

  // 点进歌手/专辑：按组过滤拉曲目。
  Future<void> openGroup(String name) async {
    state = state.copyWith(activeGroup: name);
    await load();
  }

  // 返回聚合列表（groups 已在内存，不重拉）。
  void closeGroup() {
    if (state.activeGroup == null) return;
    state = state.copyWith(clearActiveGroup: true);
  }

  // 滚动到底翻页：追加下一页，请求期间去重。搜索词变化由 load 重置列表。
  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.isLoading) return;
    final requestId = _requestId;
    state = state.copyWith(loadingMore: true);
    try {
      final result = await ref
          .read(libraryRepositoryProvider)
          .list(
            search: state.query,
            artist: _artistFilter,
            album: _albumFilter,
            folder: _folderFilter,
            limit: _pageSize,
            offset: state.items.length,
          );
      if (requestId != _requestId) return;
      state = state.copyWith(
        items: [...state.items, ...result.items],
        total: result.total,
        scan: result.scan,
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(errorMessage: failure.message);
    } finally {
      state = state.copyWith(loadingMore: false);
    }
  }

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

  // 逐个上传（服务端单文件端点）：失败跳过继续下一个，全部结束刷新列表。
  // isUploading 单飞，重复触发直接拒绝。
  Future<void> uploadFiles(List<({String path, String name})> files) async {
    if (files.isEmpty || state.isUploading) return;
    var failed = 0;
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      state = state.copyWith(
        uploadingName: file.name,
        uploadProgress: 0,
        uploadRemaining: files.length - i - 1,
        clearError: true,
      );
      try {
        await ref
            .read(libraryRepositoryProvider)
            .upload(
              file.path,
              onProgress: (sent, total) {
                if (total <= 0) return;
                state = state.copyWith(uploadProgress: sent / total);
              },
            );
      } on ApiFailure catch (failure) {
        failed += 1;
        state = state.copyWith(
          notice: HMusicNotice.error('「${file.name}」${failure.message}'),
        );
      }
    }
    state = state.copyWith(clearUploading: true);
    if (failed < files.length) {
      state = state.copyWith(
        notice: HMusicNotice.success(
          failed == 0 ? '已上传 ${files.length} 首' : '上传完成，$failed 首失败',
        ),
      );
    }
    await load();
  }

  // 触发服务端增量扫描（幂等）；完成与否经列表刷新时的 scan 字段回读。
  Future<void> scan() async {
    try {
      final scan = await ref.read(libraryRepositoryProvider).startScan();
      state = state.copyWith(
        scan: scan,
        notice: const HMusicNotice.success('已开始扫描曲库'),
        clearError: true,
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(errorMessage: failure.message);
    }
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }
}
