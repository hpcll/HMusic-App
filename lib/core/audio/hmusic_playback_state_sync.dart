part of 'hmusic_audio_handler.dart';

extension _HMusicPlaybackStateSync on HMusicAudioHandler {
  void _setServerState(server.HMusicPlaybackState state) {
    _serverState = state;
    _remoteProjector.sync(state, DateTime.now());
    // 目标为远端即开状态轮询（服务端靠被读驱动音箱回读与自动连播），回本机即停。
    _remotePoller.sync(state);
    if (!_serverStateController.isClosed) _serverStateController.add(state);
  }

  // 命令/回写响应统一落地：目标仍是本机只记状态；发现目标已被其它端切走
  //（如 Web 把播放切到音箱）立即走 _applyServerState 停本机——否则手机继续
  // 响、音箱又开播，双端同响复现。
  Future<void> _applyOrSet(server.HMusicPlaybackState state) async {
    if (state.isLocalDevice) {
      _setServerState(state);
    } else {
      await _applyServerState(state, autoplay: false);
    }
  }

  // 冷启动先恢复曲目展示，音源仅在显式播放时装载；轮询不反复重发元数据。
  void _syncMediaItem(server.HMusicPlaybackState state) {
    final track = state.track;
    if (track == null) {
      if (mediaItem.valueOrNull != null) mediaItem.add(null);
      return;
    }
    final item = mediaItemForTrack(track);
    if (mediaItem.valueOrNull?.id != item.id) mediaItem.add(item);
  }

  // 轮询回来的远端状态只做展示落地：不碰本机 player、不开周期回写。轮询窗口
  // 内目标可能被其它端切回 local-browser——那是 web 端的本机（docs/12 C-08），
  // 抢着装载/回写会互相清账；本机接管只由用户在本 App 的明确操作触发。
  void _onRemoteState(server.HMusicPlaybackState state) {
    // 竞态守卫：更早发出、更晚返回的轮询快照比当前状态旧（服务端每次变更都
    // 刷 updatedAt），直接丢弃，避免命令响应刚落地又被旧快照闪回。
    final current = _serverState;
    if (current != null && state.updatedAt < current.updatedAt) return;
    _syncMediaItem(state);
    _setServerState(state);
    _publishPlaybackState();
  }

  Future<void> _applyServerState(
    server.HMusicPlaybackState state, {
    required bool autoplay,
  }) async {
    _setServerState(state);
    final track = state.track;
    if (state.isLocalDevice && !_capabilities.supportsLocalPlayback) {
      // Server 的本机目标是共享的，可能由其他客户端选中。保持真实状态可见，
      // 不装载、不回写假播放进度，也不自动替用户改目标设备。
      _reportTimer?.cancel();
      _reportTimer = null;
      _loadedUri = null;
      _syncMediaItem(state);
      _publishPlaybackState();
      if (autoplay && track != null) _capabilities.requireLocalPlayback();
      return;
    }
    if (!state.isLocalDevice || track == null) {
      // 远端设备接管（或无曲目）：本机静默，周期回写只属于本机播放一并停掉。
      _reportTimer?.cancel();
      _reportTimer = null;
      try {
        // 平台侧装载卡死时 stop 可能永不返回（20s 装载超时只放弃 Dart 侧等待，
        // 平台加载还悬着）：切设备绝不能被本机 player 拖死，限时后继续走完。
        await _player.stop().timeout(const Duration(seconds: 3));
      } on Exception {
        // 超时/停失败不阻断：目标已是远端，本机下次装载前必先重设音源。
      }
      _loadedUri = null;
      _syncMediaItem(state);
      _publishPlaybackState();
      return;
    }

    await _applyLocalPlayback(state, track, autoplay: autoplay);
  }

  void _publishPlaybackState() {
    final projected = playbackStateProjection(
      player: _player,
      serverState: _serverState,
    );
    final restoredPosition =
        _loadedUri == null && _serverState?.isLocalDevice == true
        ? effectivePosition
        : null;
    playbackState.add(
      projected.copyWith(
        processingState: _transportBusy
            ? AudioProcessingState.loading
            : projected.processingState,
        updatePosition: restoredPosition ?? projected.updatePosition,
        bufferedPosition: restoredPosition ?? projected.bufferedPosition,
      ),
    );
  }
}
