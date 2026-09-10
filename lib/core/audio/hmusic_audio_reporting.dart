part of 'hmusic_audio_handler.dart';

extension _HMusicAudioReporting on HMusicAudioHandler {
  void _startReporting() {
    _reportTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_commands.run(_reportCurrentState)),
    );
  }

  Future<void> _reportCurrentState() async {
    if (!_capabilities.supportsLocalPlayback ||
        _loadedUri == null ||
        _reportInFlight ||
        _serverState?.deviceId != HMusicAudioHandler.localDeviceId) {
      return;
    }
    _reportInFlight = true;
    try {
      // 响应经 _applyOrSet：其它端把目标切走时（响应 deviceId 已非本机）
      // 必须立即停本机，这是双端同响的最后一条复现路径。
      await _applyOrSet(
        await _repository.reportLocal(
          state: _player.playing ? 'playing' : 'paused',
          positionMs: _player.position.inMilliseconds,
          durationMs: _player.duration?.inMilliseconds,
        ),
      );
    } on ApiFailure {
      // 周期回写失败不停止本机音频（docs/08 §6）：退避到下一周期。
      // 401 由 ApiClient→SessionController 统一处理，这里吞掉避免冒泡打断播放器。
    } finally {
      _reportInFlight = false;
    }
  }

  void _onPlayerState(PlayerState state) {
    _publishPlaybackState();
    if (state.processingState == ProcessingState.completed &&
        !_handlingEnded &&
        _serverState?.isLocalDevice == true &&
        _loadedUri != null &&
        _completedGeneration != _loadGeneration) {
      final generation = _loadGeneration;
      _completedGeneration = generation;
      unawaited(
        _commands.run(() async {
          if (generation == _loadGeneration) await _handleEnded();
        }),
      );
    }
  }

  Future<void> _handleEnded() async {
    _handlingEnded = true;
    try {
      final next = await _repository.reportLocal(ended: true);
      await _applyServerState(
        next,
        autoplay: next.state == server.PlaybackStatus.playing,
      );
    } catch (_) {
      // ended 是非幂等推进命令只发一次（docs/08 §6），失败改按 state 归并。
      // 归并自身也可能失败（断网/凭据暂不可用）——_handleEnded 是
      // fire-and-forget，异常必须就地消化，否则成未捕获错误且队列卡死。
      try {
        final latest = await _repository.getState();
        if (latest.track?.id != _serverState?.track?.id) {
          await _applyServerState(
            latest,
            autoplay: latest.state == server.PlaybackStatus.playing,
          );
        }
      } catch (_) {
        // 保持现状：等周期上报恢复或用户手动下一首时自然归并。
      }
    } finally {
      _handlingEnded = false;
    }
  }
}
