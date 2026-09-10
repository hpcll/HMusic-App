import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/hmusic_audio_handler.dart';
import '../playback/playback_mode.dart';
import '../playback/playback_mode_controller.dart';
import 'direct_providers.dart';

final directLifecycleProvider = Provider<void>((ref) {
  if (ref.watch(playbackModeProvider) != PlaybackMode.direct) return;
  final playback = ref.watch(directPlaybackRepositoryProvider);
  playback.foreground =
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  final listener = AppLifecycleListener(
    onStateChange: (state) {
      playback.foreground = state == AppLifecycleState.resumed;
      if (!playback.foreground || !ref.exists(hmusicAudioHandlerProvider)) {
        return;
      }
      unawaited(
        ref
            .read(hmusicAudioHandlerProvider.future)
            .then((handler) async {
              if (ref.mounted &&
                  ref.read(playbackModeProvider) == PlaybackMode.direct) {
                await handler.refreshPlaybackState();
              }
            })
            .catchError((Object _) {}),
      );
    },
  );
  ref.onDispose(listener.dispose);
});
