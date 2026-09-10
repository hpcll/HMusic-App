part of 'hmusic_audio_handler.dart';

// 音源装载最终失败（重解析自救也没救回来）：携带用户可读文案冒泡，前台点播
// VM 的兜底 catch 直接把它拼进错误提示，不再露 just_audio 的原始错误码。
class PlaybackLoadException implements Exception {
  const PlaybackLoadException(this.trackTitle);

  final String trackTitle;

  @override
  String toString() => '「$trackTitle」音源加载失败，可能是直链已失效';
}

extension _HMusicAudioLoading on HMusicAudioHandler {
  Future<void> _applyLocalPlayback(
    server.HMusicPlaybackState state,
    HMusicTrack track, {
    required bool autoplay,
  }) async {
    final streamUrl = state.streamUrl;
    if (streamUrl != null && streamUrl.isNotEmpty) {
      final uri = await _streamUrlRebaser.rebase(streamUrl);
      if (_loadedUri != uri ||
          _loadedTrackId != track.id ||
          _player.processingState == ProcessingState.completed) {
        try {
          // 坏直链可能既不成功也不报错（上游黑洞），必须限时：否则播放链路
          // 无声卡死在 loading，界面还顶着服务端的「正在播放」。
          await _loadTrack(
            uri,
            track,
            state.positionMs,
          ).timeout(const Duration(seconds: 20));
        } on PlayerException {
          // 直链失效恢复（docs/08 §7）：服务端快照/缓存里的 streamUrl 可能已过
          // CDN 时效（历史记录直接点播放是典型场景，AVFoundation 报 -11849）。
          await _recoverOrFail(track, state);
          return; // 恢复路径已递归走完 _applyServerState（含 autoplay）。
        } on TimeoutException {
          await _recoverOrFail(track, state);
          return;
        }
      } else if (autoplay) {
        await _player.seek(Duration(milliseconds: state.positionMs));
      }
    } else if (autoplay) {
      // playAll 等组合命令的服务端响应可能不含 streamUrl（只灌队列、不预解析
      // 直链）——必须客户端主动解析，否则 autoplay 下 _loadedUri=null 导致静默
      // 失败，或有旧 _loadedUri 但 player 已 stopped 导致 play() 空转。
      await _recoverOrFail(track, state);
      return; // 恢复路径已递归走完 _applyServerState（含 autoplay）。
    } else {
      // 纯状态同步（切设备回本机等，autoplay=false）：不解析、不装载。
      // 在这里重解析会把「切设备」拖成播放命令——链路慢/挂时设备 sheet 的
      // actingId 被一路 await 卡死（转圈 + 再也切不动），还会违背切换不自动
      // 开播的语义。用户按播放时 resume 走服务端 TTL 重解析，从原位置续播。
      _loadedUri = null;
      _publishPlaybackState();
      return;
    }
    if (autoplay && _loadedUri != null) _startPlayback();
    _startReporting();
    _publishPlaybackState();
  }

  // 装载失败的统一出口：重解析自救（60s 去抖，docs/08 §7），救回来即续播；
  // 救不回来必须如实收场，禁止停留在「正在播放」假象——
  //   1. 暂停本机 player：上一首残留的 playing 真值会让周期回写继续向服务端
  //      谎报 playing，语义状态永远回不到真实；
  //   2. 回写 paused（进度停在目标点，60s 后重试可从这续）；
  //   3. 全局通知流报错（自动切歌等无人捕获的路径全靠它出声）；
  //   4. 抛可读异常给前台点播 VM 的错误提示。
  Future<void> _recoverOrFail(
    HMusicTrack track,
    server.HMusicPlaybackState state,
  ) async {
    if (await _tryRecoverStaleUrl(track, state)) return;
    final failure = PlaybackLoadException(track.title);
    await _player.pause();
    if (!_noticeController.isClosed) _noticeController.add(failure.toString());
    try {
      _setServerState(
        await _repository.reportLocal(
          state: 'paused',
          positionMs: state.positionMs,
        ),
      );
    } on ApiFailure {
      // 回写失败不追加处理：player 已暂停，下一轮周期回写自然把 paused 带回去。
    }
    _publishPlaybackState();
    throw failure;
  }

  // 原曲重解析续播。成功返回 true（新状态已应用），不可救返回 false。
  Future<bool> _tryRecoverStaleUrl(
    HMusicTrack track,
    server.HMusicPlaybackState state,
  ) async {
    if (track.source == 'manual') return false;
    final key = '${track.source}:${track.sourceTrackId}';
    final now = DateTime.now();
    if (_recoverKey == key &&
        _recoverAt != null &&
        now.difference(_recoverAt!) < const Duration(seconds: 60)) {
      return false;
    }
    _recoverKey = key;
    _recoverAt = now;
    // 剥掉 track 里烤存的旧直链再发：服务端 resolveTrack 见 track.url 非空会
    // 短路原样返回（那是给手动直链曲目的通道），带着过期 url 去重解析等于
    // 让服务端把死链再发一遍。去掉 url 才走真正的插件解析。
    final resolvable = HMusicTrack(
      id: track.id,
      source: track.source,
      sourceTrackId: track.sourceTrackId,
      title: track.title,
      artist: track.artist,
      album: track.album,
      durationMs: track.durationMs,
      coverUrl: track.coverUrl,
      qualities: track.qualities,
      raw: track.raw, // 插件解析要用（songmid 等平台参数）。
    );
    final server.HMusicPlaybackState fresh;
    try {
      fresh = await _repository.playTrack(
        resolvable,
        queueIndex: state.queueIndex >= 0 ? state.queueIndex : null,
        positionMs: state.positionMs,
        // 直链恢复只发生在本机装载失败的分支，显式钉住本机：缺省交给服务端
        // resolve 默认设备的话，默认设备是音箱时会把本机续播劫持到音箱上。
        deviceId: HMusicAudioHandler.localDeviceId,
      );
    } on ApiFailure {
      return false; // 重解析也失败（音源死了）：交回原始加载错误。
    }
    await _applyServerState(fresh, autoplay: true);
    return true;
  }

  Future<void> _loadTrack(Uri uri, HMusicTrack track, int positionMs) async {
    _capabilities.requireLocalPlayback();
    _loadGeneration++;
    _loadedUri = null;
    _loadedTrackId = null;
    final item = mediaItemForTrack(track);
    mediaItem.add(item);
    await _player.setVolume(await _localVolumeStore.read());
    await _player.setAudioSource(
      AudioSource.uri(uri, tag: item),
      initialPosition: Duration(milliseconds: positionMs),
    );
    _loadedUri = uri;
    _loadedTrackId = track.id;
  }

  // 本机开播的唯一出口，绝不能 await：just_audio 的 play() 要等到「播完 /
  // 被暂停 / 被停」才 complete（已在播时才立即返回）。await 它会把整条播放
  // 命令挂到歌曲结束——前台点播 VM 的互斥锁一直不放（列表所有播放键变灰，
  // 症状就是「只有暂停上一首才能播下一首」）、成功 toast 延到暂停那一刻才
  // 弹（「暂停了却提示正在播放」），_handleEnded 的重入守卫也会整首歌不复位
  // 而掐断自动连播。只发出开播指令，装载错误由 setAudioSource 那边负责，
  // 播放期异常经全局通知流报出。
  void _startPlayback() {
    _capabilities.requireLocalPlayback();
    unawaited(
      _player.play().catchError((Object error) {
        reportNotice('播放失败：$error');
      }),
    );
  }
}
