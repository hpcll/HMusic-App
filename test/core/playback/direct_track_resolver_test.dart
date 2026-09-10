import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/music/direct_lx_sources.dart';
import 'package:hmusic/core/direct/music/direct_music_http.dart';
import 'package:hmusic/core/direct/music/direct_music_search.dart';
import 'package:hmusic/core/direct/music/direct_track_resolver.dart';
import 'package:hmusic/core/direct/music/lx_runtime.dart';
import 'package:hmusic/core/direct/storage/direct_local_store.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/core/storage/key_value_store.dart';

class _Runtime extends Fake implements LxRuntime {
  _Runtime(this.base);
  final Uri base;
  final qualities = <String>[];

  @override
  Future<Map<String, List<String>>> start(
    String code, {
    required String name,
  }) async => {
    'tx': ['320k', '128k'],
    'kw': ['320k', '128k'],
  };

  @override
  Future<Object?> request(
    String source,
    String action,
    Map<String, Object?> info,
  ) async {
    qualities.add('$source:${info['type']}');
    return {
      'url': base.resolve('/$source/${info['type']}.mp3').toString(),
      'headers': {'Referer': 'https://music.example/'},
    };
  }

  @override
  void close() {}
}

class _Search extends Fake implements DirectMusicSearch {
  final requests = <String>[];
  @override
  Future<List<HMusicTrack>> search(String query, {String? source}) async {
    requests.add(source!);
    return [
      HMusicTrack(
        id: '$source:matched',
        source: source,
        sourceTrackId: 'matched',
        title: '保存的歌曲',
        artist: '歌手',
        durationMs: 225000,
      ),
    ];
  }
}

void main() {
  late HttpServer server;
  late DirectMusicHttp http;
  late DirectLxSources sources;
  late DirectLocalStore store;
  late _Runtime runtime;
  late _Search search;
  final requests = <({String path, String? range, String? referer})>[];
  var highQualityStatus = 403;
  var highQualityType = 'audio/mpeg';
  var highQualityBody = <int>[];
  var rejectPlatform = false;
  const track = HMusicTrack(
    id: 'tx:saved',
    source: 'tx',
    sourceTrackId: 'saved',
    title: '保存的歌曲',
    artist: '歌手',
    durationMs: 225000,
  );

  setUp(() async {
    requests.clear();
    highQualityStatus = 403;
    highQualityType = 'audio/mpeg';
    highQualityBody = [];
    rejectPlatform = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add((
        path: request.uri.path,
        range: request.headers.value('range'),
        referer: request.headers.value('referer'),
      ));
      final rejected =
          request.uri.path.startsWith('/tx/') &&
          (rejectPlatform || request.uri.path.contains('320k'));
      request.response.statusCode = rejected ? highQualityStatus : 206;
      request.response.headers.set(
        'content-type',
        rejected ? highQualityType : 'audio/mpeg',
      );
      request.response.add(rejected ? highQualityBody : [0x49]);
      await request.response.close();
    });
    runtime = _Runtime(Uri.parse('http://127.0.0.1:${server.port}'));
    store = DirectLocalStore(MemoryKeyValueStore());
    await store.update('config', (value) => value['defaultQuality'] = '320k');
    http = DirectMusicHttp();
    sources = DirectLxSources(store, http, createRuntime: () => runtime);
    await sources.save({'id': 'fixture', 'code': 'fixture', 'enabled': true});
    search = _Search();
  });
  tearDown(() async {
    sources.close();
    http.close();
    await server.close(force: true);
  });

  test('320k 返回 403 空音频时回退 128k，保留用户音质偏好', () async {
    final audio = await DirectTrackResolver(
      sources,
      search,
      store,
    ).resolve(track);
    expect(audio.uri.path, '/tx/128k.mp3');
    expect(runtime.qualities, ['tx:320k', 'tx:128k']);
    expect(search.requests, isEmpty);
    expect(requests.map((request) => request.range), everyElement('bytes=0-0'));
    expect(
      requests.map((request) => request.referer),
      everyElement('https://music.example/'),
    );
    expect((await store.read('config'))['defaultQuality'], '320k');
    expect(sources.health['fixture'], 'ok');
  });

  for (final response in ['HTML', 'empty']) {
    test('成功状态码的 $response 响应不能冒充可播音频', () async {
      highQualityStatus = 200;
      if (response == 'HTML') {
        highQualityType = 'text/html';
        highQualityBody = '<html>error</html>'.codeUnits;
      }
      final audio = await DirectTrackResolver(
        sources,
        search,
        store,
      ).resolve(track);
      expect(audio.uri.path, '/tx/128k.mp3');
    });
  }

  test('原平台所有音质被拒绝后才匹配其他平台', () async {
    rejectPlatform = true;
    final audio = await DirectTrackResolver(
      sources,
      search,
      store,
    ).resolve(track);
    expect(audio.uri.path, '/kw/320k.mp3');
    expect(runtime.qualities, ['tx:320k', 'tx:128k', 'kw:320k']);
    expect(search.requests, ['kw']);
  });
}
