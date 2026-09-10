import 'dart:convert';

import 'package:dio/dio.dart';

import '../../models/hmusic_track.dart';
import '../../network/api_failure.dart';
import 'direct_audio_policy.dart';
import 'direct_music_http.dart';
import 'platform_track_mapper.dart';

class ImportedDirectPlaylist {
  const ImportedDirectPlaylist(this.name, this.tracks, this.total);
  final String name;
  final List<HMusicTrack> tracks;
  final int total;
}

class DirectPlaylistImporter {
  const DirectPlaylistImporter(this._http);
  final DirectMusicHttp _http;

  Future<ImportedDirectPlaylist> import(String text) async {
    try {
      return await _import(text);
    } on DioException {
      throw const ApiFailure(
        kind: ApiFailureKind.offline,
        message: '无法打开歌单分享链接，请检查网络后重试',
      );
    }
  }

  Future<ImportedDirectPlaylist> _import(String text) async {
    final urls = RegExp(r'''https?://[^\s<>"'“”]+''').allMatches(text);
    Uri? selected;
    for (final match in urls) {
      final candidate = Uri.tryParse(
        match.group(0)!.replaceAll(RegExp(r'[)）\]】》>,，。、；;！!？?]+$'), ''),
      );
      if (candidate != null && _source(candidate.host) != null) {
        selected = candidate;
        break;
      }
    }
    if (selected == null) throw _invalid;
    Uri uri = selected;
    var source = _source(uri.host)!;
    for (var redirects = 0; redirects < 5; redirects++) {
      if (uri.fragment.startsWith('/')) {
        uri = Uri.parse('${uri.origin}${uri.fragment}');
      }
      final id =
          uri.queryParameters['id'] ??
          uri.queryParameters['pid'] ??
          uri.queryParameters['disstid'] ??
          uri.queryParameters['dissid'] ??
          RegExp(
            r'/(?:playlist|playlist_detail|playsquare|details)/(\d+)',
          ).firstMatch(uri.path)?.group(1);
      if (id != null && RegExp(r'^\d+$').hasMatch(id)) return fetch(source, id);
      validateMusicUri(uri.toString());
      final response = await _http.dio.get<String>(
        uri.toString(),
        options: Options(
          followRedirects: false,
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      final location = response.headers.value('location');
      if (location == null) break;
      uri = uri.resolve(location);
      source = _source(uri.host) ?? (throw _invalid);
    }
    throw _invalid;
  }

  Future<ImportedDirectPlaylist> fetch(
    String source,
    String id, {
    int limit = 500,
  }) async {
    if (!RegExp(r'^\d+$').hasMatch(id) || limit < 1 || limit > 500) {
      throw _invalid;
    }
    final list = await switch (source) {
      'wy' => _netease(id, limit),
      'tx' => _qq(id),
      'kw' => _kuwo(id),
      _ => throw _invalid,
    };
    return ImportedDirectPlaylist(
      list.name,
      list.tracks.take(limit).toList(),
      list.total,
    );
  }

  Future<ImportedDirectPlaylist> _netease(String id, int limit) async {
    final response = await _http.json(
      'https://music.163.com/api/playlist/detail',
      query: {'id': id, 'n': limit},
      headers: {'Referer': 'https://music.163.com/'},
    );
    final list = musicMap(response['playlist'] ?? response['result']);
    if (list.isEmpty) throw _missing;
    var tracks = musicRows(
      list['tracks'],
    ).map(PlatformTrackMapper.netease).toList();
    final ids = musicRows(list['trackIds'])
        .map((entry) => '${entry['id']}')
        .where((id) => RegExp(r'^\d+$').hasMatch(id))
        .toList();
    if (ids.length > tracks.length) {
      final byId = {for (final track in tracks) track.sourceTrackId: track};
      final missing = ids
          .take(limit)
          .where((id) => !byId.containsKey(id))
          .toList();
      for (var offset = 0; offset < missing.length; offset += 100) {
        final batch = missing.skip(offset).take(100).map(int.parse).toList();
        final songs = await _http.json(
          'https://music.163.com/api/song/detail',
          query: {'ids': jsonEncode(batch)},
          headers: {'Referer': 'https://music.163.com/'},
        );
        for (final track in musicRows(
          songs['songs'],
        ).map(PlatformTrackMapper.netease)) {
          byId[track.sourceTrackId] = track;
        }
      }
      tracks = [
        for (final id in ids.take(limit))
          if (byId[id] != null) byId[id]!,
      ];
    }
    return ImportedDirectPlaylist(
      musicText(list['name']),
      tracks,
      musicInt(list['trackCount']) ??
          (ids.isNotEmpty ? ids.length : tracks.length),
    );
  }

  Future<ImportedDirectPlaylist> _qq(String id) async {
    ApiFailure? failure;
    for (final host in ['c.y.qq.com', 'i.y.qq.com']) {
      try {
        final response = await _http.json(
          'https://$host/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg',
          query: {
            'type': 1,
            'json': 1,
            'utf8': 1,
            'onlysong': 0,
            'disstid': id,
            'format': 'json',
          },
          headers: {'Referer': 'https://y.qq.com/'},
        );
        final list = musicRows(response['cdlist']).firstOrNull ?? response;
        final tracks = musicRows(
          list['songlist'],
        ).map(PlatformTrackMapper.qq).toList();
        if (tracks.isEmpty) throw _missing;
        return ImportedDirectPlaylist(
          musicText(list['dissname'] ?? list['name'] ?? 'QQ 音乐歌单'),
          tracks,
          musicInt(list['total_song_num']) ?? tracks.length,
        );
      } on ApiFailure catch (error) {
        failure = error;
      }
    }
    throw failure!;
  }

  Future<ImportedDirectPlaylist> _kuwo(String id) async {
    final response = await _http.json(
      'https://nplserver.kuwo.cn/pl.svc',
      query: {
        'op': 'getlistinfo',
        'pid': id,
        'pn': 0,
        'rn': 500,
        'encode': 'utf8',
        'keyset': 'pl2012',
        'vipver': 'MUSIC_9.0.5.0_W1',
        'newver': 1,
      },
      headers: {'Referer': 'https://www.kuwo.cn/'},
    );
    final tracks = musicRows(
      response['musiclist'] ?? response['musicList'],
    ).map(PlatformTrackMapper.kuwo).toList();
    if (tracks.isEmpty) throw _missing;
    return ImportedDirectPlaylist(
      musicText(response['name'] ?? response['title'] ?? '酷我歌单'),
      tracks,
      musicInt(response['total']) ??
          musicInt(response['totalnum']) ??
          tracks.length,
    );
  }

  String? _source(String host) {
    if (DirectAudioPolicy.hostIs(host, 'y.qq.com')) return 'tx';
    if (DirectAudioPolicy.hostIs(host, 'kuwo.cn')) return 'kw';
    if (DirectAudioPolicy.hostIs(host, 'music.163.com') ||
        DirectAudioPolicy.hostIs(host, '163cn.tv')) {
      return 'wy';
    }
    return null;
  }

  static const _invalid = ApiFailure(
    kind: ApiFailureKind.invalidConfiguration,
    message: '请粘贴 QQ 音乐、酷我或网易云的歌单分享链接',
  );
  static const _missing = ApiFailure(
    kind: ApiFailureKind.server,
    message: '歌单不存在、暂不可访问或没有可导入的歌曲',
  );
}
