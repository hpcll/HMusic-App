import '../../models/hmusic_track.dart';
import '../../network/api_failure.dart';
import '../mi_direct_device.dart';
import '../mi_direct_session.dart';
import '../mi_mina_client.dart';
import 'mi_play_message.dart';
import 'mi_speaker_commands.dart';

/// 只负责音箱指令；队列推进、解析及状态保护由直连 PlaybackRepository 持有。
class MiSpeakerPlayback {
  MiSpeakerPlayback({
    required MiMinaClient client,
    required MiSpeakerCommands commands,
    Future<void> Function(Duration)? delay,
  }) : _client = client,
       _commands = commands,
       _delay = delay ?? Future<void>.delayed;
  final MiMinaClient _client;
  final MiSpeakerCommands _commands;
  final Future<void> Function(Duration) _delay;
  String? lastAudioId;

  Future<int> play(
    MiDirectSession session,
    MiDirectDevice device, {
    required HMusicTrack track,
    required Uri stream,
    int positionMs = 0,
  }) async {
    final primary = MiPlayMessage.forTrack(
      device: device,
      track: track,
      stream: stream,
      positionMs: positionMs,
    );
    await _commands.operation(session, device, 'pause');
    await _commands.operation(session, device, 'stop');
    await _delay(const Duration(milliseconds: 500));
    var selected = primary;
    try {
      await _send(session, device, primary);
    } on ApiFailure catch (failure) {
      if (failure.code != 'MI_DIRECT_REJECTED') rethrow;
      selected = MiPlayMessage.forTrack(
        device: device,
        track: track,
        stream: stream,
        positionMs: positionMs,
        usePlayMusic: !device.profile.needsPlayMusicApi,
      );
      await _send(session, device, selected);
    }
    lastAudioId = selected.method == 'player_play_music'
        ? selected.message['startaudioid'] as String?
        : null;
    // 未带 startOffset 时单独定位，不能定位的固件如实回报从头开始。
    if (positionMs > 0 &&
        !selected.message.containsKey('startOffset') &&
        device.profile.supportsSeek) {
      try {
        await _commands.seek(session, device, positionMs);
        return positionMs;
      } on ApiFailure catch (failure) {
        if (failure.code != 'MI_DIRECT_REJECTED') rethrow;
      }
    }
    return (selected.message['startOffset'] as int?) ?? 0;
  }

  Future<void> _send(
    MiDirectSession session,
    MiDirectDevice device,
    MiPlayMessage command,
  ) async {
    await _client.ubus(
      session,
      deviceId: device.id,
      method: command.method,
      message: command.message,
    );
  }

  Future<void> pause(MiDirectSession session, MiDirectDevice device) async {
    try {
      await _commands.operation(session, device, 'pause');
    } on ApiFailure catch (failure) {
      if (!device.profile.needsStopOnPause ||
          failure.code != 'MI_DIRECT_REJECTED') {
        rethrow;
      }
    }
    if (device.profile.needsStopOnPause) {
      await _commands.operation(session, device, 'stop');
    }
  }

  Future<int> resume(
    MiDirectSession session,
    MiDirectDevice device, {
    required HMusicTrack track,
    required Uri stream,
    required int positionMs,
  }) async {
    if (device.profile.needsFullReplayOnResume) {
      return play(
        session,
        device,
        track: track,
        stream: stream,
        positionMs: positionMs,
      );
    }
    await _commands.operation(session, device, 'play');
    return positionMs;
  }
}
