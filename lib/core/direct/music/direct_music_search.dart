import '../../models/hmusic_track.dart';
import '../../network/api_failure.dart';
import 'direct_music_http.dart';
import 'platform_track_mapper.dart';

/// 沿用旧客户端 QQ Lite、酷我和网易云原生搜索，保留解析所需的原始平台字段。
class DirectMusicSearch {
  const DirectMusicSearch(this._http);
  final DirectMusicHttp _http;

  Future<List<HMusicTrack>> search(String query, {String? source}) async {
    if (query.trim().isEmpty) return [];
    if (source != null) return _platform(query.trim(), source);
    ApiFailure? failure;
    var successes = 0;
    final results = await Future.wait(
      ['tx', 'kw', 'wy'].map((platform) async {
        try {
          final result = await _platform(query.trim(), platform);
          successes++;
          return result;
        } on ApiFailure catch (error) {
          failure = error;
          return <HMusicTrack>[];
        }
      }),
    );
    if (successes == 0) throw failure!;
    final seen = <String>{};
    return results
        .expand((items) => items)
        .where((track) => seen.add(track.id))
        .toList();
  }

  Future<List<HMusicTrack>> _platform(String query, String source) async {
    final List<Map<String, Object?>> rows;
    final HMusicTrack Function(Map<String, Object?>) mapper;
    switch (source) {
      case 'tx':
        final response = await _http.json(
          'https://u.y.qq.com/cgi-bin/musicu.fcg',
          body: {
            'comm': {
              'ct': 11,
              'cv': '1003006',
              'v': '1003006',
              'os_ver': '12',
              'phonetype': '0',
              'devicelevel': '31',
              'tmeAppID': 'qqmusiclight',
              'nettype': 'NETWORK_WIFI',
            },
            'req': {
              'module': 'music.search.SearchCgiService',
              'method': 'DoSearchForQQMusicLite',
              'param': {
                'query': query,
                'search_type': 0,
                'num_per_page': 30,
                'page_num': 1,
                'nqc_flag': 0,
                'grp': 1,
              },
            },
          },
        );
        final request = musicMap(response['req']);
        if (musicInt(request['code']) != 0) throw _rejected;
        rows = musicRows(
          musicMap(musicMap(request['data'])['body'])['item_song'],
        );
        mapper = PlatformTrackMapper.qq;
      case 'kw':
        final response = await _http.json(
          'https://search.kuwo.cn/r.s',
          query: {
            'client': 'kt',
            'all': query,
            'pn': 0,
            'rn': 30,
            'uid': '794762570',
            'ver': 'kwplayer_ar_9.2.2.1',
            'vipver': 1,
            'show_copyright_off': 1,
            'newver': 1,
            'ft': 'music',
            'cluster': 0,
            'strategy': '2012',
            'encoding': 'utf8',
            'rformat': 'json',
            'vermerge': 1,
            'mobi': 1,
            'issubtitle': 1,
          },
        );
        if (response['abslist'] is! List<Object?>) throw _rejected;
        rows = musicRows(response['abslist']);
        mapper = PlatformTrackMapper.kuwo;
      case 'wy':
        final response = await _http.json(
          'https://music.163.com/api/search/get',
          query: {'s': query, 'type': 1, 'limit': 30, 'offset': 0},
          headers: {'Referer': 'https://music.163.com/'},
        );
        if (musicInt(response['code']) != 200) throw _rejected;
        rows = musicRows(musicMap(response['result'])['songs']);
        mapper = PlatformTrackMapper.netease;
      default:
        return [];
    }
    return rows
        .map(mapper)
        .where(
          (track) => track.sourceTrackId.isNotEmpty && track.title.isNotEmpty,
        )
        .toList();
  }

  static const _rejected = ApiFailure(
    kind: ApiFailureKind.server,
    code: 'DIRECT_SEARCH_REJECTED',
    message: '音乐平台暂时未接受搜索，请稍后重试',
  );
}
