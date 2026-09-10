import 'package:flutter_test/flutter_test.dart';

import 'package:hmusic/core/playback/playback_mode.dart';

void main() {
  test('mode wire values are stable', () {
    expect(PlaybackMode.server.wireName, 'server');
    expect(PlaybackMode.direct.wireName, 'direct');
  });

  test('unknown persisted values fail closed to server mode', () {
    expect(PlaybackModeWire.parse(null), PlaybackMode.server);
    expect(PlaybackModeWire.parse('legacy'), PlaybackMode.server);
    expect(PlaybackModeWire.parse('direct'), PlaybackMode.direct);
  });
}
