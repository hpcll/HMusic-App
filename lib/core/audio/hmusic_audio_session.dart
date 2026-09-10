part of 'hmusic_audio_handler.dart';

extension _HMusicAudioSession on HMusicAudioHandler {
  Future<void> _runPlayback(
    Future<void> Function() action, {
    bool showLoading = false,
  }) {
    final generation = (_backendGeneration?.call(), _backendEpoch);
    return _commands.run(() async {
      if (generation != (_backendGeneration?.call(), _backendEpoch)) {
        throw BackendRequest.changed;
      }
      if (showLoading) {
        _transportBusy = true;
        _publishPlaybackState();
      }
      try {
        await action();
      } finally {
        if (showLoading) {
          _transportBusy = false;
          _publishPlaybackState();
        }
      }
    });
  }

  Future<void> _ensureBackendState() async {
    if (_serverState != null) return;
    final state = await _repository.getState();
    _setServerState(state);
    _syncMediaItem(state);
    _publishPlaybackState();
  }

  Future<void> _pauseForTransition() async {
    final local = _serverState?.isLocalDevice == true;
    try {
      await _pausePlayback();
    } on ApiFailure catch (failure) {
      // 本机已暂停；服务器离线不能把用户困在旧模式。远端暂停仍须确认成功。
      if (!local ||
          ![
            ApiFailureKind.offline,
            ApiFailureKind.timeout,
          ].contains(failure.kind)) {
        rethrow;
      }
      reportNotice('本机播放已暂停，未能同步旧服务器的进度');
    }
  }

  Future<void> _silence() async {
    _remotePoller.stop();
    _reportTimer?.cancel();
    _reportTimer = null;
    _loadGeneration++;
    _loadedUri = null;
    _loadedTrackId = null;
    await _player.stop();
  }

  void _clearSessionState() {
    _loadedUri = null;
    _loadedTrackId = null;
    _recoverKey = null;
    _recoverAt = null;
    _handlingEnded = false;
    mediaItem.add(null);
    _setServerState(
      const server.HMusicPlaybackState(
        sessionId: 'inactive',
        state: server.PlaybackStatus.idle,
        positionMs: 0,
        durationMs: 0,
        volume: 0,
        playMode: server.PlayMode.listLoop,
        queueIndex: -1,
        queueLength: 0,
        seekEnabled: false,
        updatedAt: 0,
      ),
    );
    _serverState = null;
    _publishPlaybackState();
  }
}
