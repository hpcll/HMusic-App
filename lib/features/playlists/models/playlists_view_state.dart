import '../../../shared/models/hmusic_notice.dart';
import 'playlist.dart';

enum PlaylistsStatus { initial, loading, loaded, error }

// 歌单页状态：列表 / 详情（detail!=null）/ NAS 曲库（libraryOpen）三态同页，
// 曲库是列表顶部的系统视图（对齐 web「已下载」的同页切换心智）。
class PlaylistsViewState {
  const PlaylistsViewState({
    this.status = PlaylistsStatus.initial,
    this.playlists = const <PlaylistSummary>[],
    this.detail,
    this.detailLoading = false,
    this.libraryOpen = false,
    this.busy = false,
    this.errorMessage,
    this.notice,
  });

  final PlaylistsStatus status;
  final List<PlaylistSummary> playlists;

  // 当前打开的歌单详情；null = 列表。
  final PlaylistDetail? detail;
  final bool detailLoading;

  // NAS 曲库系统视图展开中（与详情互斥，入口只在列表页）。
  final bool libraryOpen;

  // 创建/导入/删除等写操作进行中，防连点。
  final bool busy;
  final String? errorMessage;
  final HMusicNotice? notice;

  bool get isList => detail == null && !libraryOpen;

  PlaylistsViewState copyWith({
    PlaylistsStatus? status,
    List<PlaylistSummary>? playlists,
    PlaylistDetail? detail,
    bool? detailLoading,
    bool? libraryOpen,
    bool? busy,
    String? errorMessage,
    HMusicNotice? notice,
    bool clearDetail = false,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return PlaylistsViewState(
      status: status ?? this.status,
      playlists: playlists ?? this.playlists,
      detail: clearDetail ? null : (detail ?? this.detail),
      detailLoading: detailLoading ?? this.detailLoading,
      libraryOpen: libraryOpen ?? this.libraryOpen,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}
