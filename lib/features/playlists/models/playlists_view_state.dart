import '../../../shared/models/hmusic_notice.dart';
import 'playlist.dart';

enum PlaylistsStatus { initial, loading, loaded, error }

// 歌单页状态：列表（active==null）与详情（active!=null）共用一个 state。
class PlaylistsViewState {
  const PlaylistsViewState({
    this.status = PlaylistsStatus.initial,
    this.playlists = const <PlaylistSummary>[],
    this.detail,
    this.detailLoading = false,
    this.busy = false,
    this.errorMessage,
    this.notice,
  });

  final PlaylistsStatus status;
  final List<PlaylistSummary> playlists;

  // 当前打开的歌单详情；null = 列表。
  final PlaylistDetail? detail;
  final bool detailLoading;

  // 创建/导入/删除等写操作进行中，防连点。
  final bool busy;
  final String? errorMessage;
  final HMusicNotice? notice;

  bool get isList => detail == null;

  PlaylistsViewState copyWith({
    PlaylistsStatus? status,
    List<PlaylistSummary>? playlists,
    PlaylistDetail? detail,
    bool? detailLoading,
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
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}
