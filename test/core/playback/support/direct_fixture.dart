import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/direct_device_registry.dart';
import 'package:hmusic/core/direct/mi_direct_account_repository.dart';
import 'package:hmusic/core/direct/mi_direct_session.dart';
import 'package:hmusic/core/direct/mi_direct_session_store.dart';
import 'package:hmusic/core/direct/mi_mina_client.dart';
import 'package:hmusic/core/direct/music/direct_audio_proxy.dart';
import 'package:hmusic/core/direct/music/direct_track_resolver.dart';
import 'package:hmusic/core/direct/playback/direct_playback_repository.dart';
import 'package:hmusic/core/direct/storage/direct_local_store.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/platform/client_playback_capabilities.dart';
import 'package:hmusic/core/queue/direct_queue_repository.dart';
import 'package:hmusic/core/storage/key_value_store.dart';

HMusicTrack directTrack(String id, {int? duration = 60000}) => HMusicTrack(
  id: 'wy:$id',
  source: 'wy',
  sourceTrackId: id,
  title: '曲目 $id',
  artist: '测试歌手',
  durationMs: duration,
);

class DirectSessionMemory implements MiDirectSessionStore {
  MiDirectSession? session = MiDirectSession(
    userId: '123',
    serviceToken: 'fixture-token',
  );
  @override
  Future<MiDirectSession?> read() async => session;
  @override
  Future<void> write(MiDirectSession value) async => session = value;
  @override
  Future<void> clear() async => session = null;
}

class DirectResolverFixture extends Fake implements DirectTrackResolver {
  ApiFailure? failure;
  Completer<void>? gate;
  final List<String> requests = [];
  @override
  Future<DirectResolvedAudio> resolve(HMusicTrack track) async {
    requests.add(track.id);
    await gate?.future;
    if (failure != null) throw failure!;
    return DirectResolvedAudio(
      Uri.parse('https://audio.example/${track.id}.mp3'),
    );
  }
}

class MinaFixtureAdapter implements HttpClientAdapter {
  String hardware = 'X08C';
  final List<({String method, Map<String, Object?> message})> calls = [];
  Map<String, Object?> status = {'status': 1, 'volume': 48};
  bool rejectStop = false;
  bool statusAsMap = false, malformedStatus = false;
  String? timeoutMethod;
  Completer<void>? statusGate;
  int plays = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    if (options.uri.path.endsWith('device_list')) {
      return _json([
        {
          'deviceID': 'speaker',
          'miotDID': '7',
          'name': '测试音箱',
          'hardware': hardware,
          'localip': '192.168.1.8',
        },
      ]);
    }
    final bytes = <int>[];
    if (stream != null) {
      await for (final part in stream) {
        bytes.addAll(part);
      }
    }
    final form = Uri.splitQueryString(utf8.decode(bytes));
    final method = form['method']!;
    final message = Map<String, Object?>.from(
      jsonDecode(form['message']!) as Map,
    );
    calls.add((method: method, message: message));
    if (timeoutMethod == method) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    if (method == 'player_play_operation' &&
        message['action'] == 'stop' &&
        rejectStop) {
      return _json(null, code: 500);
    }
    if (method == 'player_get_play_status') {
      final snapshot = jsonEncode(status);
      await statusGate?.future;
      return _json({
        'info': malformedStatus
            ? 'broken json'
            : statusAsMap
            ? jsonDecode(snapshot)
            : snapshot,
      });
    }
    if (method == 'player_play_music' || method == 'player_play_url') {
      plays++;
      status = {
        'status': 1,
        'volume': 48,
        'play_song_detail': {
          'audio_id': message['startaudioid'] ?? 'url-$plays',
          'position': message['startOffset'] ?? 0,
          'duration': message['duration'] ?? 0,
        },
      };
    }
    return _json({});
  }

  ResponseBody _json(Object? data, {int code = 0}) => ResponseBody.fromString(
    jsonEncode({'code': code, 'data': data}),
    200,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
  @override
  void close({bool force = false}) {}
}

class DirectFixture {
  DirectFixture({String hardware = 'X08C', MemoryKeyValueStore? preferences})
    : store = DirectLocalStore(preferences ?? MemoryKeyValueStore()) {
    adapter.hardware = hardware;
    client = MiMinaClient(adapter: adapter);
    account = MiDirectAccountRepository(client: client, store: sessionStore);
    devices = DirectDeviceRegistry(
      account,
      store,
      const ClientPlaybackCapabilities(supportsLocalPlayback: true),
    );
    queue = DirectQueueRepository(store);
    playback = createPlayback();
  }
  final MinaFixtureAdapter adapter = MinaFixtureAdapter();
  final DirectSessionMemory sessionStore = DirectSessionMemory();
  final DirectLocalStore store;
  final DirectAudioProxy proxy = DirectAudioProxy();
  final DirectResolverFixture resolver = DirectResolverFixture();
  late final MiMinaClient client;
  late final MiDirectAccountRepository account;
  late final DirectDeviceRegistry devices;
  late final DirectQueueRepository queue;
  late final DirectPlaybackRepository playback;
  DateTime now = DateTime(2026, 9, 9, 12);
  DirectPlaybackRepository createPlayback() => DirectPlaybackRepository(
    store: store,
    queue: queue,
    devices: devices,
    resolver: resolver,
    proxy: proxy,
    client: client,
    now: () => now,
    delay: (_) async {},
  );
  Future<void> init({bool remote = false}) async {
    await account.restore();
    if (remote) await devices.select('speaker');
  }

  void elapse(int seconds) => now = now.add(Duration(seconds: seconds));
  void report({int? status, int? position, int? duration, String? audioId}) {
    final old = adapter.status;
    adapter.status = {
      ...old,
      if (status != null) 'status': status,
      'play_song_detail': {
        ...?old['play_song_detail'] as Map<String, Object?>?,
        if (position != null) 'position': position,
        if (duration != null) 'duration': duration,
        if (audioId != null) 'audio_id': audioId,
      },
    };
  }

  Future<void> dispose() async {
    await playback.close();
    await proxy.dispose();
    client.close();
  }
}
