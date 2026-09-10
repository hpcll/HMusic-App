part of 'remote_playback_test.dart';

void _remotePlaybackTests() {
  test('目标为音箱的 resume：本机 player 只 stop 不拉起，状态照常落地', () async {
    final repository = _FakeRepository(resumeState: _state());
    final player = _player();
    final handler = _handler(repository, player);

    await handler.play();

    // 双端同响根因之一：旧实现漏到 _player.play() 把本机也拉响。
    verifyNever(() => player.play());
    verify(() => player.stop()).called(1);
    expect(handler.serverState?.deviceId, 'speaker-1');
    await handler.disposeHandler();
  });

  test('点歌缺省不带 deviceId；响应为音箱时本机停、mediaItem 显示音箱曲目', () async {
    final repository = _FakeRepository(playTrackState: _state());
    final player = _player();
    final handler = _handler(repository, player);

    await handler.playTrack(_track);

    // 双端同响根因之二：旧实现硬编码 local-browser，把已选音箱劫持回手机。
    expect(repository.playTrackDeviceIds.single, isNull);
    verifyNever(() => player.play());
    verify(() => player.stop()).called(1);
    // mini player/锁屏照常显示音箱在播曲目（媒体键仍走 handler → 服务端）。
    expect(handler.mediaItem.valueOrNull?.title, '晴天');
    await handler.disposeHandler();
  });

  test('目标为音箱的 seek：只发服务端，不碰本机 player', () async {
    final repository = _FakeRepository(resumeState: _state());
    final player = _player();
    final handler = _handler(repository, player);
    await handler.play(); // 进入远端态。

    await handler.seek(const Duration(seconds: 30));

    expect(repository.seekCalls, 1);
    verifyNever(() => player.seek(any()));
    await handler.disposeHandler();
  });

  test('setDeviceVolume 走服务端 0-100 通道并落地权威状态', () async {
    final repository = _FakeRepository(volumeState: _state(volume: 80));
    final player = _player();
    final handler = _handler(repository, player);

    await handler.setDeviceVolume(80);

    expect(repository.setVolumeCalls.single, 80);
    expect(handler.serverState?.volume, 80);
    // 音箱音量绝不写本机 player/本地偏好（docs/12 §4 分流铁律）。
    verifyNever(() => player.setVolume(any()));
    await handler.disposeHandler();
  });

  test('远端态启动 5s 状态轮询，目标回本机即停', () {
    fakeAsync((async) {
      final repository = _FakeRepository(resumeState: _state());
      final player = _player();
      final handler = _handler(repository, player);

      unawaited(handler.play());
      async.flushMicrotasks();
      expect(repository.getStateCalls, 0);

      // 远端态：每 5s 拉一次权威状态（驱动服务端音箱回读与自动连播）。
      async.elapse(const Duration(seconds: 5));
      expect(repository.getStateCalls, 1);
      async.elapse(const Duration(seconds: 5));
      expect(repository.getStateCalls, 2);

      // 服务端目标切回本机（如 web 端接管）：轮询停止，不再打扰。
      repository.getStateResult = _state(
        deviceId: HMusicPlaybackState.localDeviceId,
      );
      async.elapse(const Duration(seconds: 5));
      expect(repository.getStateCalls, 3);
      async.elapse(const Duration(seconds: 30));
      expect(repository.getStateCalls, 3);

      unawaited(handler.disposeHandler());
      async.flushMicrotasks();
    });
  });

  test('轮询到音箱换曲：mediaItem 跟进新曲目', () {
    fakeAsync((async) {
      final repository = _FakeRepository(resumeState: _state());
      final player = _player();
      final handler = _handler(repository, player);
      unawaited(handler.play());
      async.flushMicrotasks();

      repository.getStateResult = HMusicPlaybackState(
        sessionId: 'default',
        state: PlaybackStatus.playing,
        positionMs: 0,
        durationMs: 200000,
        volume: 60,
        playMode: PlayMode.listLoop,
        queueIndex: 1,
        queueLength: 2,
        seekEnabled: true,
        updatedAt: 0,
        deviceId: 'speaker-1',
        track: const HMusicTrack(
          id: 'tx:2',
          source: 'tx',
          sourceTrackId: '2',
          title: '七里香',
          artist: '周杰伦',
        ),
      );
      async.elapse(const Duration(seconds: 5));

      expect(handler.mediaItem.valueOrNull?.title, '七里香');
      expect(handler.serverState?.queueIndex, 1);

      unawaited(handler.disposeHandler());
      async.flushMicrotasks();
    });
  });

  test('本机在播时目标被其它端切走：周期回写响应立即停本机', () {
    fakeAsync((async) {
      final repository = _FakeRepository(
        resumeState: _state(
          deviceId: HMusicPlaybackState.localDeviceId,
          streamUrl: 'http://old.host/api/v1/proxy/audio?u=a',
        ),
        // Web 端把目标切到音箱后，回写响应的 deviceId 已是音箱。
        reportLocalState: _state(),
      );
      final player = _player();
      final handler = _handler(repository, player);

      unawaited(handler.play());
      async.flushMicrotasks();
      verify(() => player.play()).called(1);

      // 3s 周期回写返回远端目标 → 立即停本机（双端同响的最后一条复现路径）。
      async.elapse(const Duration(seconds: 3));
      verify(() => player.stop()).called(1);
      expect(handler.serverState?.deviceId, 'speaker-1');

      unawaited(handler.disposeHandler());
      async.flushMicrotasks();
    });
  });

  test('冷状态无 deviceId：不启动空轮询', () {
    fakeAsync((async) {
      final repository = _FakeRepository(
        getStateResult: _state(deviceId: null),
      );
      final player = _player();
      final handler = _handler(repository, player);

      unawaited(handler.ensureServerState());
      async.flushMicrotasks();
      expect(repository.getStateCalls, 1);

      // 全新 Server 从未播过：没有远端目标，30s 内不该有任何轮询。
      async.elapse(const Duration(seconds: 30));
      expect(repository.getStateCalls, 1);

      unawaited(handler.disposeHandler());
      async.flushMicrotasks();
    });
  });

  test('轮询快照比当前状态旧（updatedAt 更小）：丢弃不闪回', () {
    fakeAsync((async) {
      final repository = _FakeRepository(resumeState: _state(updatedAt: 2000));
      final player = _player();
      final handler = _handler(repository, player);
      unawaited(handler.play());
      async.flushMicrotasks();

      // 命令响应（updatedAt=2000）已落地，迟到的旧快照（1000）必须丢弃。
      repository.getStateResult = _state(updatedAt: 1000, volume: 99);
      async.elapse(const Duration(seconds: 5));
      expect(handler.serverState?.volume, 60);

      // 更新的快照（3000）正常落地。
      repository.getStateResult = _state(updatedAt: 3000, volume: 99);
      async.elapse(const Duration(seconds: 5));
      expect(handler.serverState?.volume, 99);

      unawaited(handler.disposeHandler());
      async.flushMicrotasks();
    });
  });

  test('冷启动接续音箱播放：ensureServerState 立即跟进 mediaItem', () async {
    final repository = _FakeRepository(getStateResult: _state());
    final player = _player();
    final handler = _handler(repository, player);

    await handler.ensureServerState();

    // mini player 不等首轮轮询（否则冷启动最多晚 5s 才出现）。
    expect(handler.mediaItem.valueOrNull?.title, '晴天');
    // playbackState 同步发布：mini 卡按钮/进度立即是远端真值，不显示停止态。
    expect(handler.playbackState.valueOrNull?.playing, isTrue);
    await handler.disposeHandler();
  });

  test('切回本机（autoplay=false、无直链）：纯状态同步，不重解析不出声', () async {
    final repository = _FakeRepository();
    final player = _player();
    final handler = _handler(repository, player);

    await handler.applyRemotePlayback(
      _state(
        deviceId: HMusicPlaybackState.localDeviceId,
        state: PlaybackStatus.paused,
      ),
      autoplay: false,
    );

    // 曾经这里会走 _recoverOrFail 重解析装载：把「切设备」拖成播放命令，
    // 链路慢/挂时设备 sheet 的 actingId 被一路 await 卡死。
    expect(repository.playTrackDeviceIds, isEmpty);
    verifyNever(() => player.play());
    verifyNever(
      () => player.setAudioSource(
        any(),
        initialPosition: any(named: 'initialPosition'),
      ),
    );
    expect(handler.serverState?.deviceId, HMusicPlaybackState.localDeviceId);
    await handler.disposeHandler();
  });

  test('本机 player stop 悬挂：切到音箱 3s 兜底完成，不被拖死', () {
    fakeAsync((async) {
      final repository = _FakeRepository();
      final player = _player();
      // 平台侧装载卡死的写照：stop 永不返回。
      when(() => player.stop()).thenAnswer((_) => Completer<void>().future);
      final handler = _handler(repository, player);

      var applied = false;
      unawaited(
        handler
            .applyRemotePlayback(_state(), autoplay: false)
            .then((_) => applied = true),
      );
      async.flushMicrotasks();
      expect(applied, isFalse); // stop 悬着，切换还没走完。

      async.elapse(const Duration(seconds: 3));
      expect(applied, isTrue); // 3s 兜底放行，切换完成。
      expect(handler.serverState?.deviceId, 'speaker-1');

      unawaited(handler.disposeHandler());
      async.flushMicrotasks();
    });
  });
}
