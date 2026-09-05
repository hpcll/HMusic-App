import '../../../core/models/hmusic_track.dart';

enum SearchStatus { idle, searching, loaded }

class SearchViewState {
  const SearchViewState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.tracks = const <HMusicTrack>[],
    this.playingTrackId,
    this.errorMessage,
  });

  final SearchStatus status;
  final String query;
  final List<HMusicTrack> tracks;
  final String? playingTrackId;
  final String? errorMessage;

  bool get isSearching => status == SearchStatus.searching;
  bool get hasSearched => status == SearchStatus.loaded;

  SearchViewState copyWith({
    SearchStatus? status,
    String? query,
    List<HMusicTrack>? tracks,
    String? playingTrackId,
    String? errorMessage,
    bool clearError = false,
    bool clearPlayingTrack = false,
  }) {
    return SearchViewState(
      status: status ?? this.status,
      query: query ?? this.query,
      tracks: tracks ?? this.tracks,
      playingTrackId: clearPlayingTrack
          ? null
          : playingTrackId ?? this.playingTrackId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
