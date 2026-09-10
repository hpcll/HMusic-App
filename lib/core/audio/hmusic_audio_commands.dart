part of 'hmusic_audio_handler.dart';

extension _HMusicAudioCommands on HMusicAudioHandler {
  Future<void> _playTrack(HMusicTrack track, int? queueIndex) async {
    _requireSupportedTarget();
    final state = await _repository.playTrack(track, queueIndex: queueIndex);
    await _applyServerState(state, autoplay: true);
  }

  Future<void> _resumePlayback() async {
    _requireSupportedTarget();
    final state = await _repository.resume();
    if (!state.isLocalDevice) {
      await _applyServerState(state, autoplay: false);
      return;
    }
    if (state.streamUrl?.isNotEmpty ?? false) {
      await _applyServerState(state, autoplay: true);
      return;
    }
    final track = state.track;
    if (track != null && _loadedUri == null) {
      _setServerState(state);
      await _recoverOrFail(track, state);
      return;
    }
    if (track == null) {
      await _applyServerState(state, autoplay: false);
      return;
    }
    _startPlayback();
    _startReporting();
    _publishPlaybackState();
  }

  Future<void> _pausePlayback() async {
    await _player.pause();
    await _applyOrSet(await _repository.pause());
    await _reportCurrentState();
    _publishPlaybackState();
  }

  Future<void> _seekPlayback(Duration position) async {
    if (_serverState?.isLocalDevice ?? false) {
      _capabilities.requireLocalPlayback();
      await _player.seek(position);
    }
    await _applyOrSet(await _repository.seek(position.inMilliseconds));
    _publishPlaybackState();
  }

  Future<void> _stopPlayback() async {
    _reportTimer?.cancel();
    _reportTimer = null;
    await _player.stop();
    _setServerState(await _repository.stop());
    _loadedUri = null;
    _loadedTrackId = null;
    _loadGeneration++;
    _publishPlaybackState();
  }
}
