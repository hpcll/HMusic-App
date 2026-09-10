import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/music/direct_music_http.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/features/search/data/search_repository.dart';
import 'package:hmusic/features/search/models/search_result.dart';

class ChartHttpFixture extends Fake implements DirectMusicHttp {
  final requests =
      <({String url, Map<String, Object?>? query, Object? body})>[];
  FutureOr<Map<String, Object?>> Function(String, Object?)? reply;
  String html = '';

  @override
  Future<Map<String, Object?>> json(
    String url, {
    Map<String, Object?>? query,
    Object? body,
    Map<String, Object?>? headers,
  }) async {
    requests.add((url: url, query: query, body: body));
    return await reply?.call(url, body) ?? {};
  }

  @override
  Future<String> text(
    String url, {
    Map<String, Object?>? query,
    Object? body,
    Map<String, Object?>? headers,
  }) async {
    requests.add((url: url, query: query, body: body));
    return html;
  }
}

class ChartSearchFixture implements SearchRepository {
  final requests = <String>[];
  Future<List<HMusicTrack>> Function(String)? reply;

  @override
  Future<SearchResult> search(String query) async {
    requests.add(query);
    final tracks = await reply?.call(query) ?? [];
    return SearchResult(
      query: query,
      page: 1,
      limit: 50,
      total: tracks.length,
      tracks: tracks,
    );
  }
}
