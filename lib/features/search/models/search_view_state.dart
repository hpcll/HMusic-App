import '../../../core/models/hmusic_track.dart';
import '../../../shared/models/hmusic_notice.dart';

enum SearchStatus { idle, searching, loaded }

class SearchViewState {
  const SearchViewState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.tracks = const <HMusicTrack>[],
    this.playingTrackId,
    this.errorMessage,
    this.notice,
  });

  final SearchStatus status;
  final String query;
  final List<HMusicTrack> tracks;
  final String? playingTrackId;
  final String? errorMessage;

  // 一次性成功提示（如"已加入队列"），页面展示后调 clearNotice 消费掉。
  final HMusicNotice? notice;

  bool get isSearching => status == SearchStatus.searching;
  bool get hasSearched => status == SearchStatus.loaded;

  SearchViewState copyWith({
    SearchStatus? status,
    String? query,
    List<HMusicTrack>? tracks,
    String? playingTrackId,
    String? errorMessage,
    HMusicNotice? notice,
    bool clearError = false,
    bool clearPlayingTrack = false,
    bool clearNotice = false,
  }) {
    return SearchViewState(
      status: status ?? this.status,
      query: query ?? this.query,
      tracks: tracks ?? this.tracks,
      playingTrackId: clearPlayingTrack
          ? null
          : playingTrackId ?? this.playingTrackId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      notice: clearNotice ? null : notice ?? this.notice,
    );
  }
}
