import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/hmusic_audio_handler.dart';
import 'package:hmusic/core/audio/local_volume_store.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/audio/playback_repository.dart';
import 'package:hmusic/core/audio/stream_url_rebaser.dart';
import 'package:hmusic/core/config/server_config_store.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/platform/client_playback_capabilities.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

part 'support/remote_playback_fixture.dart';
part 'remote_playback_capability_cases.dart';
part 'remote_playback_state_cases.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
    registerFallbackValue(_FakeAudioSource());
  });

  _capabilityTests();
  _remotePlaybackTests();
}
