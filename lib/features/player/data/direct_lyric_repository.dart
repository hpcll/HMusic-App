import 'dart:convert';

import '../../../core/direct/music/direct_lx_sources.dart';
import '../../../core/direct/music/direct_music_http.dart';
import '../../../core/direct/music/lx_music_info.dart';
import '../../../core/direct/music/platform_track_mapper.dart';
import '../../../core/models/hmusic_track.dart';
import '../../../core/network/api_failure.dart';
import '../models/hmusic_lyric.dart';
import 'lyric_repository.dart';

class DirectLyricRepository implements LyricRepository {
  const DirectLyricRepository(this._http, this._sources);
  final DirectMusicHttp _http;
  final DirectLxSources _sources;

  @override
  Future<HMusicLyric> fetchLyric(HMusicTrack track) async {
    String lrc = '';
    try {
      switch (track.source) {
        case 'wy':
          final data = await _http.json(
            'https://music.163.com/api/song/lyric',
            query: {'id': track.sourceTrackId, 'lv': -1, 'kv': -1, 'tv': -1},
            headers: {'Referer': 'https://music.163.com/'},
          );
          lrc = '${musicMap(data['lrc'])['lyric'] ?? ''}';
        case 'tx':
          final data = await _http.json(
            'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg',
            query: {
              'songmid': track.sourceTrackId,
              'format': 'json',
              'nobase64': 1,
            },
            headers: {'Referer': 'https://y.qq.com/'},
          );
          lrc = '${data['lyric'] ?? ''}';
          if (lrc.isNotEmpty && !lrc.contains('[')) {
            try {
              lrc = utf8.decode(base64Decode(lrc));
            } on FormatException {
              /* 非编码的纯文本歌词。 */
            }
          }
          lrc = lrc
              .replaceAll('&#58;', ':')
              .replaceAll('&#46;', '.')
              .replaceAll('&#10;', '\n')
              .replaceAll('&#13;', '')
              .replaceAll('&#32;', ' ')
              .replaceAll('&amp;', '&');
        case 'kw':
          final data = await _http.json(
            'https://m.kuwo.cn/newh5/singles/songinfoandlrc',
            query: {'musicId': track.sourceTrackId},
          );
          final lines =
              musicRows(musicMap(data['data'])['lrclist'])
                  .map(
                    (line) => LyricLine(
                      timeMs: ((double.tryParse('${line['time']}') ?? 0) * 1000)
                          .round(),
                      text: '${line['lineLyric'] ?? ''}',
                    ),
                  )
                  .where((line) => line.text.trim().isNotEmpty)
                  .toList()
                ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
          if (lines.isNotEmpty) {
            return HMusicLyric(
              trackId: track.id,
              source: track.source,
              lines: lines,
            );
          }
      }
    } on ApiFailure {
      /* 平台接口失败时沿用已配置音源的歌词接口。 */
    }
    if (lrc.isEmpty && ['tx', 'wy', 'kw'].contains(track.source)) {
      try {
        final result = await _sources.resolve(track.source, 'lyric', {
          'musicInfo': lxMusicInfo(track),
        });
        lrc = result is String ? result : '${musicMap(result)['lyric'] ?? ''}';
      } on ApiFailure {
        /* 没有歌词是合法空态。 */
      }
    }
    return HMusicLyric(
      trackId: track.id,
      source: track.source,
      lrc: lrc,
      lines: parseDirectLrc(lrc),
    );
  }
}

List<LyricLine> parseDirectLrc(String lrc) {
  final offset =
      int.tryParse(
        RegExp(r'\[offset:([+-]?\d+)\]').firstMatch(lrc)?.group(1) ?? '',
      ) ??
      0;
  final stamp = RegExp(r'\[(\d+):(\d{2})(?:[.:](\d{1,3}))?\]');
  final result = <LyricLine>[];
  for (final line in const LineSplitter().convert(lrc)) {
    final matches = stamp.allMatches(line).toList();
    if (matches.isEmpty) continue;
    final text = line.substring(matches.last.end).trim();
    for (final match in matches) {
      final milliseconds = int.parse((match.group(3) ?? '0').padRight(3, '0'));
      result.add(
        LyricLine(
          timeMs:
              (int.parse(match.group(1)!) * 60000 +
                      int.parse(match.group(2)!) * 1000 +
                      milliseconds +
                      offset)
                  .clamp(0, 1 << 52),
          text: text,
        ),
      );
    }
  }
  return result..sort((a, b) => a.timeMs.compareTo(b.timeMs));
}
