part of 'direct_playback_repository.dart';

extension _DirectPlaybackSync on DirectPlaybackRepository {
  void _schedule(HMusicPlaybackState state) {
    _deadline =
        !state.isLocalDevice &&
            _ownsRemote &&
            state.state == PlaybackStatus.playing &&
            state.durationMs > 0
        ? _now().add(
            Duration(
              milliseconds: max(0, state.durationMs - state.positionMs) + 2000,
            ),
          )
        : null;
  }

  HMusicPlaybackState _project() {
    final state = _state!;
    if (state.isLocalDevice || state.state != PlaybackStatus.playing) {
      return state;
    }
    final elapsed = max(0, _now().millisecondsSinceEpoch - state.updatedAt);
    return state.update(
      positionMs: (state.positionMs + elapsed).clamp(
        0,
        state.durationMs > 0 ? state.durationMs : (1 << 52),
      ),
      updatedAt: _now().millisecondsSinceEpoch,
    );
  }

  Future<HMusicPlaybackState> _synchronize() async {
    final queue = await _queue.getQueue();
    _state = _state!.update(
      queueIndex: queue.currentIndex,
      queueLength: queue.items.length,
      playMode: queue.playMode,
      updatedAt: _state!.updatedAt,
    );
    var state = _state!;
    if (state.isLocalDevice ||
        !foreground ||
        state.track == null ||
        (!_ownsRemote && !_needsVerification)) {
      return state;
    }
    final lifecycle = _lifecycleGeneration;
    final device = (await _devices.device(state.deviceId!))!;
    final info = MiSpeakerStatus(
      await _commands.status(await _devices.account.session(), device),
    );
    if (!foreground || lifecycle != _lifecycleGeneration) return _state!;
    _devices.confirmOnline(device.id);
    final protected =
        _commandProtectedUntil != null &&
        _now().isBefore(_commandProtectedUntil!);
    final sameId = _remoteAudioId != null && info.audioId == _remoteAudioId;

    // 重启/回前台必须核实同一播放实例；无法确认时只展示暂停态，不接管音箱其它内容。
    if (_needsVerification) {
      _needsVerification = false;
      if (!sameId) return _releaseRemote(state);
      _ownsRemote = true;
      if (info.playing && info.positionMs != null) {
        state = state.update(
          status: PlaybackStatus.playing,
          positionMs: max(0, info.positionMs!),
          updatedAt: _now().millisecondsSinceEpoch,
        );
        _state = state;
        _observedRemotePlaying = true;
        // 回前台保留离开前的截止时间；冷启动才依据已核实的进度重新计时。
        if (_deadline == null) _schedule(state);
      } else if (info.paused || info.stopped) {
        _deadline = null;
        return _commit(state.update(status: PlaybackStatus.paused));
      }
    }
    if (info.audioId != null && _remoteAudioId != null && !sameId) {
      if (protected) return _commit(_project());
      return _releaseRemote(state);
    }
    if (_remoteAudioId == null && info.audioId != null && info.playing) {
      // URL API 由音箱分配 audio_id；仅在进度、时长与刚发出的命令相符时绑定。
      final expected = _project().positionMs;
      final position = info.positionMs;
      final duration = info.durationMs;
      if (position != null &&
          (position - expected).abs() <= 15000 &&
          (state.durationMs == 0 ||
              duration == null ||
              duration == 0 ||
              (duration - state.durationMs).abs() <= 15000)) {
        _remoteAudioId = info.audioId;
      } else if (!protected) {
        return _releaseRemote(state);
      }
    }

    if (info.playing && state.state == PlaybackStatus.playing) {
      _observedRemotePlaying = true;
      await _recordHistory();
    }
    state = _project();
    if (info.volume != null) {
      state = state.update(volume: info.volume!.clamp(0, 100));
    }
    final reportedDuration = info.durationMs;
    final oldDuration = state.durationMs;
    if (reportedDuration != null &&
        reportedDuration > 0 &&
        !(reportedDuration < 10000 && state.durationMs > 30000)) {
      state = state.update(durationMs: reportedDuration);
    }
    final position = info.positionMs;
    final positionChanged = position != null && position != _lastRemotePosition;
    final stalled =
        !positionChanged &&
        _lastRemoteProgressAt != null &&
        _now().difference(_lastRemoteProgressAt!) >=
            const Duration(seconds: 15);
    final reliable = !device.profile.hasUnreliablePlayStatus;
    final deadlineReached = _deadline != null && !_now().isBefore(_deadline!);
    final wrapped =
        !protected &&
        position != null &&
        position < 10000 &&
        (_lastRemotePosition ?? 0) > 10000 &&
        state.durationMs > 0 &&
        state.durationMs - _lastRemotePosition! <= 6000;
    final nearEnd =
        state.durationMs > 0 &&
        (position ?? _lastRemotePosition ?? 0) >= state.durationMs - 1500;
    final naturalStop =
        reliable &&
        info.stopped &&
        _observedRemotePlaying &&
        (state.durationMs == 0
            ? (_lastRemotePosition ?? 0) > 0
            : deadlineReached || nearEnd);

    if (state.state == PlaybackStatus.playing && !protected) {
      if (wrapped ||
          naturalStop ||
          (deadlineReached &&
              (!reliable || info.playing || nearEnd) &&
              (position == null || position == 0 || nearEnd || stalled))) {
        return _advance(automatic: true);
      }
      if (reliable && (info.paused || info.stopped) && _observedRemotePlaying) {
        _deadline = null;
        return _commit(state.update(status: PlaybackStatus.paused));
      }
    }
    if (!protected &&
        positionChanged &&
        position >= 0 &&
        (state.durationMs == 0 || position <= state.durationMs) &&
        (position > 0 || state.positionMs < 10000)) {
      state = state.update(positionMs: position);
      _lastRemotePosition = position;
      _lastRemoteProgressAt = _now();
      _schedule(state);
    } else if (state.durationMs > 0 &&
        (_deadline == null || oldDuration != state.durationMs)) {
      _schedule(state);
    }
    return _commit(state);
  }

  Future<HMusicPlaybackState> _releaseRemote(HMusicPlaybackState state) {
    _ownsRemote = false;
    _deadline = null;
    _remoteStream = null;
    _remoteResolvedAt = null;
    _remoteAudioId = null;
    return _commit(state.update(status: PlaybackStatus.paused));
  }
}
