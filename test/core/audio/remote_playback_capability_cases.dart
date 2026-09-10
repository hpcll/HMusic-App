part of 'remote_playback_test.dart';

void _capabilityTests() {
  test('无本机后端：Server 返回本机曲目时如实失败，不装载/播放/回写', () async {
    final local = _state(
      deviceId: 'local-browser',
      streamUrl: 'http://127.0.0.1:8090/api/v1/proxy/audio/test',
    );
    final repository = _FakeRepository(playTrackState: local);
    final player = _player();
    final handler = _handler(repository, player, localSupported: false);
    await expectLater(
      handler.playTrack(_track),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.code,
          'code',
          'LOCAL_PLAYBACK_UNAVAILABLE',
        ),
      ),
    );
    expect(handler.serverState?.deviceId, 'local-browser');
    expect(handler.mediaItem.valueOrNull?.title, '晴天');
    verifyNever(
      () => player.setAudioSource(
        any(),
        initialPosition: any(named: 'initialPosition'),
      ),
    );
    verifyNever(() => player.play());
    await handler.disposeHandler();
  });

  test('无本机后端：已知本机目标的控件/快捷键操作不能绕过门禁', () async {
    final local = _state(deviceId: 'local-browser');
    final repository = _FakeRepository(getStateResult: local);
    final player = _player();
    final handler = _handler(repository, player, localSupported: false);
    await handler.ensureServerState();
    for (final action in <Future<void> Function()>[
      handler.play,
      handler.skipToNext,
      handler.skipToPrevious,
      () => handler.playTrack(_track),
      () => handler.seek(const Duration(seconds: 30)),
      () => handler.setLocalVolume(.7),
    ]) {
      await expectLater(action(), throwsA(isA<ApiFailure>()));
    }
    expect(repository.playTrackDeviceIds, isEmpty);
    expect(repository.seekCalls, 0);
    verifyNever(() => player.setVolume(any()));
    verifyNever(() => player.seek(any()));
    await handler.disposeHandler();
  });

  test('无本机后端：音箱播放、seek、音量仍走唯一 handler', () async {
    final repository = _FakeRepository();
    final player = _player();
    final handler = _handler(repository, player, localSupported: false);
    await handler.playTrack(_track);
    await handler.play();
    await handler.seek(const Duration(seconds: 30));
    await handler.setDeviceVolume(80);
    expect(repository.playTrackDeviceIds, [null]);
    expect(repository.seekCalls, 1);
    expect(repository.setVolumeCalls, [80]);
    verifyNever(() => player.play());
    verifyNever(() => player.seek(any()));
    expect(handler.serverState?.deviceId, 'speaker-1');
    await handler.disposeHandler();
  });
}
