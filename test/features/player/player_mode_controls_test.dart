import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/platform/client_playback_capabilities.dart';
import 'package:hmusic/core/playback/playback_mode.dart';
import 'package:hmusic/core/playback/playback_mode_controller.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/features/player/widgets/player_device_status.dart';
import 'package:hmusic/features/player/widgets/player_output_button.dart';

void main() {
  testWidgets(
    'player hides mobile/desktop output actions and disables status picker',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          clientPlaybackCapabilitiesProvider.overrideWithValue(
            const ClientPlaybackCapabilities(supportsLocalPlayback: true),
          ),
        ],
      );
      addTearDown(container.dispose);
      const state = HMusicPlaybackState(
        sessionId: 'direct',
        deviceId: 'local-browser',
        state: PlaybackStatus.paused,
        positionMs: 0,
        durationMs: 0,
        volume: 50,
        playMode: PlayMode.listLoop,
        queueIndex: 0,
        queueLength: 0,
        seekEnabled: true,
        updatedAt: 0,
      );
      await container
          .read(playbackModeProvider.notifier)
          .select(PlaybackMode.player);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: HMusicTheme.light(),
            home: const Scaffold(
              body: Column(
                children: [
                  PlayerOutputButton(state: state),
                  PlayerOutputButton(state: state, showLabel: true),
                  PlayerDeviceStatus(state: state),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
      await container
          .read(playbackModeProvider.notifier)
          .select(PlaybackMode.direct);
      await tester.pump();
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
      final status = find.descendant(
        of: find.byType(PlayerDeviceStatus),
        matching: find.byType(InkWell),
      );
      expect(tester.widget<InkWell>(status).onTap, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
