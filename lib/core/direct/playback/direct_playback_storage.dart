part of 'direct_playback_repository.dart';

extension _DirectPlaybackStorage on DirectPlaybackRepository {
  Future<void> _restore() async {
    if (_state != null) return;
    final saved = await _store.read('playback');
    final id = await _devices.selectedId();
    _state = saved.isEmpty
        ? HMusicPlaybackState(
            sessionId: 'direct',
            deviceId: id,
            deviceName: id == HMusicPlaybackState.localDeviceId
                ? '本机播放'
                : '小爱音箱',
            state: PlaybackStatus.idle,
            positionMs: 0,
            durationMs: 0,
            volume: 50,
            playMode: PlayMode.listLoop,
            queueIndex: -1,
            queueLength: 0,
            seekEnabled: true,
            updatedAt: _now().millisecondsSinceEpoch,
          )
        : HMusicPlaybackState.fromJson(saved).update(
            deviceId: id,
            status: saved['track'] == null
                ? PlaybackStatus.idle
                : PlaybackStatus.paused,
            clearStream: true,
          );
    final ownerUserId = await _devices.account.storedUserId();
    _remoteAudioId =
        ownerUserId != null &&
            saved['deviceId'] == id &&
            saved['ownerUserId'] == ownerUserId
        ? saved['remoteAudioId'] as String?
        : null;
    _needsVerification = !_state!.isLocalDevice && _state!.track != null;
    _historyRecorded = true;
    final instance = await _store.update(
      'devices',
      (data) => data['instanceId'] ??= List.generate(
        16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
    );
    _commands = MiSpeakerCommands(client: _client, instanceId: '$instance');
    _speaker = MiSpeakerPlayback(
      client: _client,
      commands: _commands,
      delay: _delay,
    );
  }

  Future<HMusicPlaybackState> _commit(HMusicPlaybackState state) async {
    final stamp = max(
      _now().millisecondsSinceEpoch,
      (_state?.updatedAt ?? 0) + 1,
    );
    final updated = state.update(updatedAt: stamp);
    final ownerUserId = _ownsRemote
        ? await _devices.account.storedUserId()
        : null;
    await _store.update('playback', (data) {
      data
        ..clear()
        ..addAll(updated.update(clearStream: true).toJson());
      if (_ownsRemote && _remoteAudioId != null) {
        data['remoteAudioId'] = _remoteAudioId;
      }
      if (ownerUserId != null) data['ownerUserId'] = ownerUserId;
    });
    _state = updated;
    return updated;
  }

  Future<void> _recordHistory() async {
    final track = _state?.track;
    if (_historyRecorded || track == null) return;
    _historyRecorded = true;
    try {
      await _store.update('history', (data) {
        final events = musicRows(data['events']);
        data['events'] = [
          ...events.skip(max(0, events.length - 4999)),
          {'track': track.toJson(), 'playedAt': _now().millisecondsSinceEpoch},
        ];
      });
    } catch (_) {
      // 统计写入失败不打断已经开始的播放。
    }
  }
}
