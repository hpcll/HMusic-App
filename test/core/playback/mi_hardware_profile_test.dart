import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/mi_hardware_profile.dart';

void main() {
  test('OH2P requires full replay and disables inaccurate seek', () {
    final profile = MiHardwareProfile(' oh2p ');
    expect(profile.playMethod, 'player_play_music');
    expect(profile.needsFullReplayOnResume, isTrue);
    expect(profile.supportsStartOffset, isFalse);
    expect(profile.supportsSeek, isFalse);
    expect(profile.hasUnreliablePlayStatus, isTrue);
    expect(profile.needsStopOnPause, isFalse);
  });

  test('speaker model selection follows the server exact-match table', () {
    expect(MiHardwareProfile('L06').playMethod, 'player_play_url');
    for (final model in ['L06A', 'LX06', 'L15A', 'L16A', 'L17A']) {
      expect(MiHardwareProfile(model).playMethod, 'player_play_music');
    }
    expect(MiHardwareProfile('L06A-extra').playMethod, 'player_play_url');
    expect(MiHardwareProfile('L05B').needsFullReplayOnResume, isFalse);
  });

  test('custom model normalization never matches unrelated substrings', () {
    expect(
      MiHardwareProfile(' l20a ', extraModels: ['L20A']).needsPlayMusicApi,
      isTrue,
    );
    expect(
      MiHardwareProfile('L20AX', extraModels: ['L20A']).needsPlayMusicApi,
      isFalse,
    );
    expect(MiHardwareProfile('', extraModels: ['']).needsPlayMusicApi, isFalse);
  });

  test('S12A replays on resume and uses seek instead of startOffset', () {
    final profile = MiHardwareProfile('S12A');
    expect(profile.playMethod, 'player_play_url');
    expect(profile.needsStopOnPause, isTrue);
    expect(profile.needsFullReplayOnResume, isTrue);
    expect(profile.supportsStartOffset, isFalse);
    expect(profile.supportsSeek, isTrue);
    expect(profile.media, 'app_android');
  });

  test('unknown models keep legacy optimistic capabilities', () {
    final profile = MiHardwareProfile('');
    expect(profile.playMethod, 'player_play_url');
    expect(profile.supportsSeek, isTrue);
    expect(profile.needsStopOnPause, isFalse);
    expect(profile.hasUnreliablePlayStatus, isFalse);
  });
}
