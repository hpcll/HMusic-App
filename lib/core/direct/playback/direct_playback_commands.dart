part of 'direct_playback_repository.dart';

extension _DirectPlaybackCommands on DirectPlaybackRepository {
  Future<HMusicPlaybackState> _play(
    HMusicTrack track, {
    int? queueIndex,
    int positionMs = 0,
    String? deviceId,
    List<HMusicTrack>? replacement,
    bool recordHistory = true,
    bool Function()? isCurrent,
    void Function(int revision)? onQueueReplaced,
  }) async {
    _requireCurrent(isCurrent);
    final id = deviceId ?? await _devices.selectedId();
    final device = await _devices.device(id);
    var queue = await _queue.getQueue();
    if (replacement == null &&
        queueIndex != null &&
        (queueIndex < 0 ||
            queueIndex >= queue.items.length ||
            queue.items[queueIndex].track.id != track.id)) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '队列已变化，请刷新后重试',
      );
    }
    final audio = await _resolver.resolve(track);
    final config = await _store.read('config');
    final stream = await _proxy.address(
      audio,
      remote: device != null,
      deviceIp: device?.ip,
      advertisedHost: config['proxyHost'] as String?,
      qqDirect: config['qqDirect'] == true,
    );
    _requireCurrent(isCurrent);
    if (_state!.deviceId != id) await _stopRemote();
    var position = positionMs.clamp(0, track.durationMs ?? (1 << 52));
    if (device != null) {
      _deadline = null;
      try {
        position = await _speaker.play(
          await _devices.account.session(),
          device,
          track: track,
          stream: stream,
          positionMs: position,
        );
        _devices.confirmOnline(device.id);
      } catch (_) {
        // 非幂等指令可能已在音箱执行；保留目标供用户显式停止，不自动重发或推进。
        _ownsRemote = true;
        _remoteStream = null;
        _remoteResolvedAt = null;
        _remoteAudioId = null;
        await _commit(
          _state!.update(
            status: PlaybackStatus.paused,
            deviceId: id,
            deviceName: device.name,
            track: track,
            clearStream: true,
          ),
        );
        rethrow;
      }
    }
    if (replacement != null) {
      _requireCurrent(isCurrent);
      final replacing = _queue.replaceQueue(
        tracks: replacement,
        currentIndex: queueIndex,
      );
      onQueueReplaced?.call(_queue.revision);
      queue = await replacing;
      _requireCurrent(isCurrent);
    } else {
      var index =
          queueIndex ??
          queue.items.indexWhere((item) => item.track.id == track.id);
      if (index < 0) {
        queue = await _queue.addTrack(track);
        index = queue.items.length - 1;
      }
      queue = await _queue.setCurrentIndex(index);
    }
    await _devices.select(id);
    _remoteStream = device == null ? null : stream;
    _remoteResolvedAt = device == null ? null : _now();
    _remoteAudioId = device == null ? null : _speaker.lastAudioId;
    _ownsRemote = device != null;
    _needsVerification = false;
    _historyRecorded = !recordHistory;
    _lastRemotePosition = null;
    _lastRemoteProgressAt = null;
    _commandProtectedUntil = _now().add(const Duration(seconds: 8));
    _observedRemotePlaying = false;
    final state = _state!.update(
      status: PlaybackStatus.playing,
      track: track,
      deviceId: id,
      deviceName: device?.name ?? '本机播放',
      positionMs: position,
      durationMs: track.durationMs ?? 0,
      queueIndex: queue.currentIndex,
      queueLength: queue.items.length,
      playMode: queue.playMode,
      seekEnabled: device?.profile.supportsSeek ?? true,
      streamUrl: device == null ? stream.toString() : null,
      clearStream: device != null,
    );
    _schedule(state);
    return _commit(state);
  }

  Future<HMusicPlaybackState> _pause() async {
    final state = _project();
    if (!state.isLocalDevice && state.track != null && _ownsRemote) {
      final device = await _devices.device(state.deviceId!);
      await _speaker.pause(await _devices.account.session(), device!);
    }
    _deadline = null;
    _commandProtectedUntil = _now().add(const Duration(seconds: 3));
    return _commit(state.update(status: PlaybackStatus.paused));
  }

  Future<HMusicPlaybackState> _resume() async {
    final state = _state!, track = _state!.track;
    if (track == null) return _advance();
    if (state.isLocalDevice ||
        _remoteStream == null ||
        _remoteResolvedAt == null ||
        _now().difference(_remoteResolvedAt!) >= const Duration(minutes: 20) ||
        state.state == PlaybackStatus.stopped) {
      return _play(
        track,
        positionMs: state.positionMs,
        queueIndex: state.queueIndex >= 0 ? state.queueIndex : null,
        recordHistory: false,
      );
    }
    final device = (await _devices.device(state.deviceId!))!;
    final position = await _speaker.resume(
      await _devices.account.session(),
      device,
      track: track,
      stream: _remoteStream!,
      positionMs: state.positionMs,
    );
    final resumed = state.update(
      status: PlaybackStatus.playing,
      positionMs: position,
    );
    if (device.profile.needsFullReplayOnResume) {
      _remoteAudioId = _speaker.lastAudioId;
    }
    _ownsRemote = true;
    _needsVerification = false;
    _observedRemotePlaying = false;
    _lastRemotePosition = null;
    _lastRemoteProgressAt = null;
    _commandProtectedUntil = _now().add(const Duration(seconds: 8));
    _schedule(resumed);
    return _commit(resumed);
  }

  Future<HMusicPlaybackState> _stop() async {
    await _stopRemote();
    _queue.cancelPendingAppends();
    _deadline = null;
    _remoteStream = null;
    _remoteResolvedAt = null;
    _ownsRemote = false;
    _remoteAudioId = null;
    return _commit(
      _state!.update(
        status: PlaybackStatus.stopped,
        positionMs: 0,
        clearStream: true,
      ),
    );
  }

  Future<void> _stopRemote() async {
    final state = _state!;
    if (_ownsRemote &&
        !state.isLocalDevice &&
        state.track != null &&
        (state.state == PlaybackStatus.playing ||
            state.state == PlaybackStatus.paused)) {
      final device = (await _devices.device(state.deviceId!))!;
      await _commands.operation(
        await _devices.account.session(),
        device,
        'stop',
      );
    }
  }

  Future<HMusicPlaybackState> _seek(int positionMs) async {
    final state = _state!;
    final target = positionMs.clamp(
      0,
      state.durationMs > 0 ? state.durationMs : (1 << 52),
    );
    if (!state.isLocalDevice) {
      if (!_ownsRemote) {
        throw const ApiFailure(
          kind: ApiFailureKind.invalidConfiguration,
          message: '音箱当前播放已变化，请重新点播歌曲',
        );
      }
      final device = (await _devices.device(state.deviceId!))!;
      await _commands.seek(await _devices.account.session(), device, target);
    }
    final updated = state.update(positionMs: target);
    _lastRemotePosition = null;
    _lastRemoteProgressAt = null;
    _commandProtectedUntil = _now().add(const Duration(seconds: 3));
    _schedule(updated);
    return _commit(updated);
  }

  Future<HMusicPlaybackState> _advance({
    bool automatic = false,
    bool previous = false,
  }) async {
    final queue = await _queue.getQueue();
    final length = queue.items.length;
    if (length == 0 || (automatic && queue.playMode == PlayMode.singleOnce)) {
      return _stop();
    }
    var index = queue.currentIndex + (previous ? -1 : 1);
    if (automatic && queue.playMode == PlayMode.singleLoop) {
      index = queue.currentIndex;
    }
    if (!previous && queue.playMode == PlayMode.shuffle && length > 1) {
      index = (queue.currentIndex + 1 + Random().nextInt(length - 1)) % length;
    }
    if (automatic && queue.playMode == PlayMode.sequence && index >= length) {
      return _stop();
    }
    index = (index % length + length) % length;
    _deadline = null;
    try {
      return await _play(queue.items[index].track, queueIndex: index);
    } catch (_) {
      // 自动推进失败后停在暂停态，不让下轮轮询重发并跳过队列。
      if (automatic) {
        try {
          await _stopRemote();
        } catch (_) {
          /* 原错误由调用者显示。 */
        }
        await _commit(_state!.update(status: PlaybackStatus.paused));
      }
      rethrow;
    }
  }

  void _requireCurrent(bool Function()? isCurrent) {
    if (isCurrent != null && !isCurrent()) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        code: 'DIRECT_CHART_PLAY_CANCELLED',
        message: '榜单播放已被新的队列操作取消',
      );
    }
  }
}
