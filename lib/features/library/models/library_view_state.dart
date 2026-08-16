import '../../../shared/models/hmusic_notice.dart';
import 'library_item.dart';

enum LibraryStatus { idle, loading, loaded }

// 分类分段：全部曲目 / 按歌手 / 按专辑 / 按文件夹聚合。
enum LibrarySection { all, artists, albums, folders }

class LibraryViewState {
  const LibraryViewState({
    this.status = LibraryStatus.idle,
    this.items = const <LibraryItem>[],
    this.total = 0,
    this.query = '',
    this.loadingMore = false,
    this.section = LibrarySection.all,
    this.groups = const <LibraryGroup>[],
    this.groupsLoading = false,
    this.activeGroup,
    this.scan,
    this.playingTrackId,
    this.uploadingName,
    this.uploadProgress = 0,
    this.uploadRemaining = 0,
    this.errorMessage,
    this.notice,
  });

  final LibraryStatus status;
  final List<LibraryItem> items;
  final int total;
  final String query;
  final bool loadingMore;
  final LibrarySection section;
  final List<LibraryGroup> groups;
  final bool groupsLoading;

  // 选中的歌手/专辑名；非空时列表按其过滤，空则展示聚合列表。
  final String? activeGroup;
  final LibraryScanInfo? scan;
  final String? playingTrackId;

  // 上传队列：当前文件名 + 进度（0-1）+ 排队中的剩余个数。
  final String? uploadingName;
  final double uploadProgress;
  final int uploadRemaining;
  final String? errorMessage;
  final HMusicNotice? notice;

  bool get isLoading => status == LibraryStatus.loading;

  bool get hasMore => items.length < total;

  bool get isUploading => uploadingName != null;

  // 当前是否展示聚合列表（歌手/专辑分段且未点进具体组）。
  bool get showsGroups => section != LibrarySection.all && activeGroup == null;

  LibraryViewState copyWith({
    LibraryStatus? status,
    List<LibraryItem>? items,
    int? total,
    String? query,
    bool? loadingMore,
    LibrarySection? section,
    List<LibraryGroup>? groups,
    bool? groupsLoading,
    String? activeGroup,
    LibraryScanInfo? scan,
    String? playingTrackId,
    String? uploadingName,
    double? uploadProgress,
    int? uploadRemaining,
    String? errorMessage,
    HMusicNotice? notice,
    bool clearPlayingTrack = false,
    bool clearUploading = false,
    bool clearActiveGroup = false,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return LibraryViewState(
      status: status ?? this.status,
      items: items ?? this.items,
      total: total ?? this.total,
      query: query ?? this.query,
      loadingMore: loadingMore ?? this.loadingMore,
      section: section ?? this.section,
      groups: groups ?? this.groups,
      groupsLoading: groupsLoading ?? this.groupsLoading,
      activeGroup: clearActiveGroup ? null : activeGroup ?? this.activeGroup,
      scan: scan ?? this.scan,
      playingTrackId: clearPlayingTrack
          ? null
          : playingTrackId ?? this.playingTrackId,
      uploadingName: clearUploading
          ? null
          : uploadingName ?? this.uploadingName,
      uploadProgress: clearUploading
          ? 0
          : uploadProgress ?? this.uploadProgress,
      uploadRemaining: clearUploading
          ? 0
          : uploadRemaining ?? this.uploadRemaining,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      notice: clearNotice ? null : notice ?? this.notice,
    );
  }
}
