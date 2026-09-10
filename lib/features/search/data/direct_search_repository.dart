import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/direct/music/direct_music_search.dart';
import '../../../core/direct/music/platform_track_mapper.dart';
import '../../../core/direct/storage/direct_local_store.dart';
import '../../../core/models/hmusic_track.dart';
import '../models/search_result.dart';
import 'search_repository.dart';

class DirectSearchRepository implements SearchRepository {
  const DirectSearchRepository(this._search, this._store);
  final DirectMusicSearch _search;
  final DirectLocalStore _store;
  @override
  Future<SearchResult> search(String query) async {
    final config = await _store.read('config');
    final manual = musicRows(config['manualTracks'])
        .where(
          (track) => '${track['title']} ${track['artist']}'
              .toLowerCase()
              .contains(query.trim().toLowerCase()),
        )
        .map((track) {
          final id = sha1.convert(utf8.encode('${track['url']}')).toString();
          return HMusicTrack(
            id: 'manual:$id',
            source: 'manual',
            sourceTrackId: id,
            title: '${track['title']}',
            artist: '${track['artist'] ?? ''}',
            url: '${track['url']}',
          );
        })
        .toList();
    var online = <HMusicTrack>[];
    try {
      online = await _search.search(query);
    } catch (_) {
      if (manual.isEmpty) rethrow;
    }
    final preferred = switch (config['searchStrategy']) {
      'kuwoFirst' => 'kw',
      'neteaseFirst' => 'wy',
      _ => 'tx',
    };
    final tracks = [
      ...manual,
      ...online.where((track) => track.source == preferred),
      ...online.where((track) => track.source != preferred),
    ];
    return SearchResult(
      query: query,
      page: 1,
      limit: tracks.length,
      total: tracks.length,
      tracks: tracks,
    );
  }
}
