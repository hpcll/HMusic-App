import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:hmusic/core/audio/hmusic_audio_handler.dart';
import 'package:hmusic/core/audio/local_volume_store.dart';
import 'package:hmusic/core/audio/mode_stream_url_rebaser.dart';
import 'package:hmusic/core/config/shared_preferences_server_config_store.dart';
import 'package:hmusic/core/direct/direct_device_registry.dart';
import 'package:hmusic/core/direct/mi_direct_account_repository.dart';
import 'package:hmusic/core/direct/mi_direct_session.dart';
import 'package:hmusic/core/direct/mi_direct_session_store.dart';
import 'package:hmusic/core/direct/mi_mina_client.dart';
import 'package:hmusic/core/direct/music/direct_audio_proxy.dart';
import 'package:hmusic/core/direct/music/direct_lx_sources.dart';
import 'package:hmusic/core/direct/music/direct_music_http.dart';
import 'package:hmusic/core/direct/music/direct_music_search.dart';
import 'package:hmusic/core/direct/music/direct_track_resolver.dart';
import 'package:hmusic/core/direct/playback/direct_playback_repository.dart';
import 'package:hmusic/core/direct/storage/direct_local_store.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/core/platform/client_playback_capabilities.dart';
import 'package:hmusic/core/playback/playback_mode.dart';
import 'package:hmusic/core/queue/direct_queue_repository.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:just_audio/just_audio.dart';

// 默认使用内存与合成音频；进程重启验证可注入隔离存储，不读取用户账号或业务存储。
class _NoSession implements MiDirectSessionStore {
  @override
  Future<MiDirectSession?> read() async => null;
  @override
  Future<void> write(MiDirectSession session) async {}
  @override
  Future<void> clear() async {}
}

class _QuietVolume implements LocalVolumeStore {
  @override
  Future<double> read() async => .1;
  @override
  Future<void> write(double volume) async {}
}

class DirectAudioHarness {
  DirectAudioHarness({
    this.initialData = const {},
    this.createPlayer,
    this.duration = const Duration(seconds: 4),
    KeyValueStore? preferences,
  }) : preferences = preferences ?? MemoryKeyValueStore();
  final Map<String, String> initialData;
  final AudioPlayer Function()? createPlayer;
  final Duration duration;
  final KeyValueStore preferences;
  final http = DirectMusicHttp();
  final mina = MiMinaClient();
  final proxy = DirectAudioProxy();
  late final store = DirectLocalStore(preferences);
  late final queue = DirectQueueRepository(store);
  late final sources = DirectLxSources(store, http);
  late final playback = DirectPlaybackRepository(
    store: store,
    queue: queue,
    proxy: proxy,
    client: mina,
    devices: DirectDeviceRegistry(
      MiDirectAccountRepository(client: mina, store: _NoSession()),
      store,
      const ClientPlaybackCapabilities(supportsLocalPlayback: true),
    ),
    resolver: DirectTrackResolver(sources, DirectMusicSearch(http), store),
  );
  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;
  HMusicAudioHandler? _handler;
  HMusicAudioHandler get handler => _handler!;
  int requests = 0;

  HMusicTrack track(String id) => HMusicTrack(
    id: 'wy:fixture-$id',
    source: 'wy',
    sourceTrackId: 'fixture-$id',
    title: '直连集成测试 $id',
    artist: '本机合成音频',
    durationMs: duration.inMilliseconds,
  );

  Future<void> initialize() async {
    for (final entry in initialData.entries) {
      await preferences.setString(entry.key, entry.value);
    }
    final server = _server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final wave = _wave(duration);
    _subscription = server.listen((request) async {
      requests++;
      final range = RegExp(
        r'bytes=(\d+)-(\d*)',
      ).firstMatch(request.headers.value('range') ?? '');
      final start = int.tryParse(range?.group(1) ?? '') ?? 0;
      final end = (int.tryParse(range?.group(2) ?? '') ?? wave.length - 1)
          .clamp(0, wave.length - 1);
      request.response.headers.set('content-type', 'audio/wav');
      request.response.headers.set('accept-ranges', 'bytes');
      if (start > end) {
        request.response.statusCode = 416;
      } else {
        if (range != null) {
          request.response.statusCode = 206;
          request.response.headers.set(
            'content-range',
            'bytes $start-$end/${wave.length}',
          );
        }
        request.response.contentLength = end - start + 1;
        if (request.method != 'HEAD') {
          request.response.add(wave.sublist(start, end + 1));
        }
      }
      await request.response.close();
    });
    final plugins = await sources.list();
    if (plugins.isEmpty ||
        (plugins.length == 1 && plugins.single['id'] == 'integration')) {
      await sources.save({
        'id': 'integration',
        'name': '本机验证音源',
        'enabled': true,
        'code':
            '''
lx.on('request', () => ${jsonEncode('http://127.0.0.1:${server.port}/fixture.wav')});
lx.send('inited', {status: true, sources: {
  wy: {actions: ['musicUrl'], qualitys: ['128k', '320k']}
}});
''',
      });
    }
    await AudioSession.instance.then(
      (session) => session.configure(const AudioSessionConfiguration.music()),
    );
    _handler = await AudioService.init(
      builder: () => HMusicAudioHandler(
        player: createPlayer?.call(),
        playbackRepository: playback,
        streamUrlRebaser: ModeStreamUrlRebaser(
          serverConfigStore: SharedPreferencesServerConfigStore(
            preferences: preferences,
          ),
          mode: () => PlaybackMode.direct,
        ),
        localVolumeStore: _QuietVolume(),
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.hupc.hmusic.test',
        androidNotificationChannelName: 'HMusic 集成验证',
      ),
    );
  }

  Future<void> dispose() async {
    await _handler?.transitionBackend(() async {});
    await _handler?.disposeHandler();
    await playback.close();
    sources.close();
    await proxy.dispose();
    http.close();
    mina.close();
    await _server?.close(force: true);
    await _subscription?.cancel();
  }
}

Uint8List _wave(Duration duration) {
  const rate = 22050;
  final samples = rate * duration.inMilliseconds ~/ 1000;
  final data = ByteData(44 + samples * 2);
  void tag(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      data.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  data.setUint32(4, data.lengthInBytes - 8, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    data.setInt16(
      44 + i * 2,
      (sin(2 * pi * 440 * i / rate) * 500).round(),
      Endian.little,
    );
  }
  return data.buffer.asUint8List();
}
