import 'dart:convert';

import '../../../core/direct/music/direct_music_http.dart';
import '../../../core/direct/music/direct_playlist_importer.dart';
import '../../../core/direct/music/platform_track_mapper.dart';
import '../../../core/network/api_failure.dart';
import '../models/chart.dart';
import '../models/direct_chart_catalog.dart';
import 'direct_family_chart.dart';

/// 仅访问公开榜单元数据；Apple/Spotify 的播放仍走现有音源搜索与解析。
class DirectChartSource {
  const DirectChartSource(this._http, this._importer);
  final DirectMusicHttp _http;
  final DirectPlaylistImporter _importer;

  Future<List<ChartEntry>> fetch(DirectChartDefinition definition) async {
    final id = definition.upstreamId;
    final entries = switch (definition.chart.kind) {
      'netease' => [
        for (final (index, track) in (await _importer.fetch(
          'wy',
          id,
          limit: 50,
        )).tracks.indexed)
          chartEntryForTrack(track, index + 1),
      ],
      'qq' => await _qq(int.parse(id)),
      'apple' => await _apple(id),
      'spotify-public' => await _spotify(id),
      _ => throw _invalid,
    };
    if (entries.isEmpty) throw _invalid;
    return entries;
  }

  Future<List<ChartEntry>> _qq(int topId) async {
    Future<List<Map<String, Object?>>> songs([String? period]) async {
      final data = await _qqRequest('GetDetail', {
        'topId': topId,
        'offset': 0,
        'num': 50,
        if (period != null) 'period': period,
      });
      return musicRows(data['songInfoList']);
    }

    var rows = await songs();
    if (rows.isEmpty) {
      final catalog = await _qqRequest('GetAll', {});
      final matching = musicRows(catalog['group'])
          .expand((group) => musicRows(group['toplist']))
          .where((item) => musicInt(item['topId']) == topId)
          .firstOrNull;
      final period = matching?['period']?.toString();
      if (period != null && period.isNotEmpty) rows = await songs(period);
    }
    return [
      for (final (index, track)
          in rows
              .take(50)
              .map(PlatformTrackMapper.qq)
              .where((t) => t.title.isNotEmpty && t.sourceTrackId.isNotEmpty)
              .indexed)
        chartEntryForTrack(track, index + 1),
    ];
  }

  Future<Map<String, Object?>> _qqRequest(
    String method,
    Map<String, Object?> param,
  ) async {
    final payload = await _http.json(
      'https://u.y.qq.com/cgi-bin/musicu.fcg',
      headers: {'Referer': 'https://y.qq.com/'},
      body: {
        'comm': {'ct': 24, 'cv': 0},
        'toplist': {
          'module': 'musicToplist.ToplistInfoServer',
          'method': method,
          'param': param,
        },
      },
    );
    final result = musicMap(payload['toplist']);
    if (musicInt(result['code']) != 0) throw _invalid;
    return musicMap(result['data']);
  }

  Future<List<ChartEntry>> _apple(String region) async {
    final payload = await _http.json(
      'https://rss.marketingtools.apple.com/api/v2/$region/music/most-played/50/songs.json',
    );
    final songs = musicRows(musicMap(payload['feed'])['results']).where(
      (song) =>
          musicText(song['name']).isNotEmpty &&
          musicText(song['artistName']).isNotEmpty,
    );
    return [
      for (final (index, song) in songs.take(50).indexed)
        ChartEntry(
          rank: index + 1,
          title: musicText(song['name']),
          artist: musicText(song['artistName']),
          coverUrl: song['artworkUrl100']?.toString().replaceFirst(
            '100x100',
            '600x600',
          ),
        ),
    ];
  }

  Future<List<ChartEntry>> _spotify(String playlistId) async {
    final html = await _http.text(
      'https://open.spotify.com/embed/playlist/$playlistId',
    );
    final json = RegExp(
      r'<script\b[^>]*\bid="__NEXT_DATA__"[^>]*>([\s\S]*?)</script>',
    ).firstMatch(html)?.group(1);
    if (json == null) throw _invalid;
    final Map<String, Object?> root;
    try {
      root = musicMap(jsonDecode(json));
    } on FormatException {
      throw _invalid;
    }
    final page = musicMap(musicMap(root['props'])['pageProps']);
    final entity = musicMap(
      musicMap(musicMap(page['state'])['data'])['entity'],
    );
    if (entity['id'] != playlistId) throw _invalid;
    final cover = musicRows(
      musicMap(entity['coverArt'])['sources'],
    ).firstOrNull?['url']?.toString();
    final songs = musicRows(entity['trackList']).where(
      (song) =>
          song['entityType'] == 'track' && musicText(song['title']).isNotEmpty,
    );
    return [
      for (final (index, song) in songs.take(50).indexed)
        ChartEntry(
          rank: index + 1,
          title: musicText(song['title']),
          artist: musicText(song['subtitle']).replaceAll('\u00a0', ' '),
          coverUrl: cover,
        ),
    ];
  }

  static const _invalid = ApiFailure(
    kind: ApiFailureKind.invalidResponse,
    code: 'DIRECT_CHART_INVALID',
    message: '音乐平台暂未返回有效榜单，请稍后重试',
  );
}
