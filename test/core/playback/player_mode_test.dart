import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/api_playback_repository.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/direct/direct_providers.dart';
import 'package:hmusic/core/direct/mi_direct_account_repository.dart';
import 'package:hmusic/core/direct/mi_direct_providers.dart';
import 'package:hmusic/core/direct/mi_direct_session.dart';
import 'package:hmusic/core/direct/mi_direct_session_store.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/platform/client_playback_capabilities.dart';
import 'package:hmusic/core/playback/playback_mode.dart';
import 'package:hmusic/core/playback/playback_mode_controller.dart';
import 'package:hmusic/core/playback/playback_mode_store.dart';
import 'package:hmusic/core/playback/playback_mode_switch.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/queue/api_queue_repository.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/features/settings/data/api_devices_repository.dart';
import 'package:hmusic/features/settings/data/api_settings_repository.dart';

import 'support/direct_fixture.dart';

class _ForbiddenSession implements MiDirectSessionStore {
  int reads = 0;
  @override
  Future<MiDirectSession?> read() async {
    reads++;
    throw StateError('Player mode must not read Xiaomi credentials');
  }

  @override
  Future<void> write(MiDirectSession session) async =>
      throw StateError('write');
  @override
  Future<void> clear() async => throw StateError('clear');
}

void main() {
  late MemoryKeyValueStore preferences;
  late DirectFixture fixture;
  late _ForbiddenSession session;
  late ProviderContainer container;

  ProviderContainer createContainer({bool localPlayback = true}) =>
      ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(preferences),
          clientPlaybackCapabilitiesProvider.overrideWithValue(
            ClientPlaybackCapabilities(supportsLocalPlayback: localPlayback),
          ),
          miMinaClientProvider.overrideWithValue(fixture.client),
          miDirectAccountRepositoryProvider.overrideWithValue(
            MiDirectAccountRepository(client: fixture.client, store: session),
          ),
          directTrackResolverProvider.overrideWithValue(fixture.resolver),
          directAudioProxyProvider.overrideWithValue(fixture.proxy),
        ],
      );

  setUp(() async {
    preferences = MemoryKeyValueStore();
    fixture = DirectFixture(preferences: preferences);
    session = _ForbiddenSession();
    await PlaybackModeStore(
      preferences: preferences,
    ).write(PlaybackMode.player);
    container = createContainer();
    await container.read(playbackModeProvider.notifier).restore();
  });
  tearDown(() async {
    container.dispose();
    await fixture.dispose();
  });

  test(
    'player restores, plays and advances locally without either account',
    () async {
      final playback = container.read(playbackRepositoryProvider);
      final queue = container.read(queueRepositoryProvider);
      await queue.replaceQueue(tracks: [directTrack('1'), directTrack('2')]);
      final playing = await playback.playTrack(directTrack('1'), queueIndex: 0);
      expect(playing.isLocalDevice, isTrue);
      expect(playing.streamUrl, 'https://audio.example/wy:1.mp3');
      await playback.reportLocal(state: 'playing', positionMs: 12000);
      await playback.pause();
      expect((await playback.resume()).positionMs, 12000);
      expect((await playback.reportLocal(ended: true)).track?.id, 'wy:2');
      expect(session.reads, 0);
      expect(fixture.adapter.calls, isEmpty);
    },
  );

  test(
    'cold restore overrides stale speaker target without losing its selection',
    () async {
      await fixture.store.update(
        'devices',
        (data) => data['selectedId'] = 'speaker',
      );
      await fixture.store.update(
        'playback',
        (data) => data.addAll({
          'sessionId': 'direct',
          'deviceId': 'speaker',
          'deviceName': '旧音箱',
          'state': 'playing',
          'track': directTrack('saved').toJson(),
          'positionMs': 37000,
          'durationMs': 60000,
          'seekEnabled': false,
          'volume': 50,
          'playMode': 'list_loop',
          'queueIndex': 0,
          'queueLength': 1,
          'updatedAt': 1,
        }),
      );
      final playback = container.read(playbackRepositoryProvider);
      final restored = await playback.getState();
      expect(restored.isLocalDevice, isTrue);
      expect(restored.deviceName, '本机播放');
      expect(restored.seekEnabled, isTrue);
      expect(restored.state, PlaybackStatus.paused);
      expect(restored.positionMs, 37000);
      expect(restored.streamUrl, isNull);
      expect((await playback.resume()).positionMs, 37000);
      expect((await fixture.store.read('devices'))['selectedId'], 'speaker');
      await expectLater(
        container.read(directDeviceRegistryProvider).select('speaker'),
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'PLAYER_LOCAL_ONLY'),
        ),
      );
      await container.read(devicesRepositoryProvider).refresh();
      await container.read(settingsRepositoryProvider).loadSummary();
      expect(session.reads, 0);
      expect(fixture.adapter.calls, isEmpty);
    },
  );

  test(
    'player round trip retains queue and position with real routed providers',
    () async {
      final playback = container.read(playbackRepositoryProvider);
      await playback.playTrack(directTrack('saved'));
      await playback.reportLocal(state: 'playing', positionMs: 23000);
      final switching = container.read(playbackModeSwitchProvider.notifier);
      expect(await switching.select(PlaybackMode.server), isTrue);
      expect(await switching.select(PlaybackMode.player), isTrue);
      final restored = await playback.getState();
      expect(restored.positionMs, 23000);
      expect(restored.state, PlaybackStatus.paused);
      expect(
        (await container.read(queueRepositoryProvider).getQueue())
            .items
            .single
            .track
            .id,
        'wy:saved',
      );
      container.dispose();
      container = createContainer();
      expect(
        await container.read(playbackModeProvider.notifier).restore(),
        PlaybackMode.player,
      );
      expect(
        (await container.read(playbackRepositoryProvider).getState())
            .positionMs,
        23000,
      );
      expect(session.reads, 0);
    },
  );

  test('unsupported host does not restore a saved player mode', () async {
    container.dispose();
    container = createContainer(localPlayback: false);
    expect(
      await container.read(playbackModeProvider.notifier).restore(),
      PlaybackMode.server,
    );
    expect(
      await container
          .read(playbackModeSwitchProvider.notifier)
          .select(PlaybackMode.player),
      isFalse,
    );
    expect(session.reads, 0);
  });
}
