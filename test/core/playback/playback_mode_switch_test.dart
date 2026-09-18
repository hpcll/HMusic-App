import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/hmusic_audio_handler.dart';
import 'package:hmusic/core/direct/direct_providers.dart';
import 'package:hmusic/core/direct/direct_session_providers.dart';
import 'package:hmusic/core/direct/mi_direct_providers.dart';
import 'package:hmusic/core/platform/client_playback_capabilities.dart';
import 'package:hmusic/core/playback/playback_mode.dart';
import 'package:hmusic/core/playback/playback_mode_controller.dart';
import 'package:hmusic/core/playback/playback_mode_switch.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';

import '../audio/support/audio_fixture.dart';
import 'support/direct_fixture.dart';

void main() {
  late ProviderContainer container;
  late DirectFixture fixture;
  setUp(() {
    fixture = DirectFixture();
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        miDirectAccountRepositoryProvider.overrideWithValue(fixture.account),
        directPlaybackRepositoryProvider.overrideWithValue(fixture.playback),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await fixture.dispose();
  });

  test(
    'connection mode selection works before media service initialization',
    () async {
      final coordinator = container.read(playbackModeSwitchProvider.notifier);
      expect(await coordinator.select(PlaybackMode.direct), isTrue);
      expect(container.exists(hmusicAudioHandlerProvider), isFalse);
      expect(container.read(playbackModeProvider), PlaybackMode.direct);
      expect(await coordinator.select(PlaybackMode.server), isTrue);
      expect(container.read(playbackModeProvider), PlaybackMode.server);
    },
  );

  test(
    'unsupported player switch leaves the active speaker untouched',
    () async {
      container.dispose();
      final audio = AudioFixture(fixture.playback);
      addTearDown(audio.handler.disposeHandler);
      container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          miDirectAccountRepositoryProvider.overrideWithValue(fixture.account),
          directPlaybackRepositoryProvider.overrideWithValue(fixture.playback),
          hmusicAudioHandlerProvider.overrideWith((ref) async => audio.handler),
          clientPlaybackCapabilitiesProvider.overrideWithValue(
            const ClientPlaybackCapabilities(supportsLocalPlayback: false),
          ),
        ],
      );
      await container
          .read(playbackModeProvider.notifier)
          .select(PlaybackMode.direct);
      await container.read(hmusicAudioHandlerProvider.future);
      await fixture.init(remote: true);
      container.read(directPlaybackRepositoryProvider);
      await audio.handler.playTrack(directTrack('speaker'));
      fixture.adapter.calls.clear();

      expect(
        await container
            .read(playbackModeSwitchProvider.notifier)
            .select(PlaybackMode.player),
        isFalse,
      );
      expect(container.read(playbackModeProvider), PlaybackMode.direct);
      expect(
        container.read(playbackModeSwitchProvider).error,
        ClientPlaybackCapabilities.localPlaybackUnavailableReason,
      );
      expect(fixture.adapter.calls, isEmpty);
      expect(audio.handler.serverState?.track?.id, 'wy:speaker');
      expect(fixture.sessionStore.session, isNotNull);
    },
  );

  test('unobserved direct target is paused before switching modes', () async {
    await container
        .read(playbackModeProvider.notifier)
        .select(PlaybackMode.direct);
    await fixture.init(remote: true);
    await container
        .read(directPlaybackRepositoryProvider)
        .playTrack(directTrack('1'));
    expect(container.exists(hmusicAudioHandlerProvider), isFalse);
    expect(
      await container
          .read(playbackModeSwitchProvider.notifier)
          .select(PlaybackMode.server),
      isTrue,
    );
    expect(
      fixture.adapter.calls.any((call) => call.message['action'] == 'pause'),
      isTrue,
    );
    expect(container.read(playbackModeProvider), PlaybackMode.server);
  });

  test(
    'stop failure preserves mode and credentials with a retryable error',
    () async {
      await container
          .read(playbackModeProvider.notifier)
          .select(PlaybackMode.direct);
      await fixture.init(remote: true);
      await container
          .read(directPlaybackRepositoryProvider)
          .playTrack(directTrack('1'));
      fixture.adapter.rejectStop = true;
      expect(
        await container
            .read(playbackModeSwitchProvider.notifier)
            .logoutDirect(),
        isFalse,
      );
      expect(container.read(playbackModeProvider), PlaybackMode.direct);
      expect(fixture.sessionStore.session, isNotNull);
      expect(container.read(playbackModeSwitchProvider).error, isNotNull);
    },
  );

  test(
    'logout stops target before clearing credentials and retains local queue',
    () async {
      await container
          .read(playbackModeProvider.notifier)
          .select(PlaybackMode.direct);
      await fixture.init(remote: true);
      await container
          .read(directPlaybackRepositoryProvider)
          .playTrack(directTrack('1'));
      expect(
        await container
            .read(playbackModeSwitchProvider.notifier)
            .logoutDirect(),
        isTrue,
      );
      expect(fixture.sessionStore.session, isNull);
      expect(container.read(directSessionControllerProvider).isInvalid, isTrue);
      expect((await fixture.queue.getQueue()).items, hasLength(1));
      expect(fixture.adapter.calls.last.message['action'], 'stop');
    },
  );

  test('切换模式保留原模式曲目和精确暂停位置，再切回来可以续播', () async {
    container.dispose();
    final audio = AudioFixture(fixture.playback);
    addTearDown(audio.handler.disposeHandler);
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        miDirectAccountRepositoryProvider.overrideWithValue(fixture.account),
        directPlaybackRepositoryProvider.overrideWithValue(fixture.playback),
        hmusicAudioHandlerProvider.overrideWith((ref) async => audio.handler),
      ],
    );
    await container
        .read(playbackModeProvider.notifier)
        .select(PlaybackMode.direct);
    await container.read(hmusicAudioHandlerProvider.future);
    await fixture.init();
    await audio.handler.playTrack(directTrack('saved'));
    await audio.handler.seek(const Duration(seconds: 37));

    final switching = container.read(playbackModeSwitchProvider.notifier);
    expect(await switching.select(PlaybackMode.server), isTrue);
    expect(audio.player.playing, isFalse);
    expect((await fixture.store.read('playback'))['positionMs'], 37000);
    expect(fixture.sessionStore.session, isNotNull);
    expect((await fixture.queue.getQueue()).items.single.track.id, 'wy:saved');

    expect(await switching.select(PlaybackMode.direct), isTrue);
    await audio.handler.ensureServerState();
    expect(audio.handler.effectivePosition.inSeconds, 37);
    await audio.handler.play();
    expect(audio.player.playing, isTrue);
    expect(audio.player.position.inSeconds, 37);
  });

  test('Handler 已控制直连音箱时切换只发送一次暂停', () async {
    container.dispose();
    final audio = AudioFixture(fixture.playback);
    addTearDown(audio.handler.disposeHandler);
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        miDirectAccountRepositoryProvider.overrideWithValue(fixture.account),
        directPlaybackRepositoryProvider.overrideWithValue(fixture.playback),
        hmusicAudioHandlerProvider.overrideWith((ref) async => audio.handler),
      ],
    );
    await container
        .read(playbackModeProvider.notifier)
        .select(PlaybackMode.direct);
    await container.read(hmusicAudioHandlerProvider.future);
    await fixture.init(remote: true);
    container.read(directPlaybackRepositoryProvider);
    await audio.handler.playTrack(directTrack('speaker'));
    fixture.adapter.calls.clear();
    expect(
      await container
          .read(playbackModeSwitchProvider.notifier)
          .select(PlaybackMode.server),
      isTrue,
    );
    expect(
      fixture.adapter.calls.where((call) => call.message['action'] == 'pause'),
      hasLength(1),
    );
  });
}
