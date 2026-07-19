import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/audio/playback_projection.dart';
import 'package:hmusic/core/models/hmusic_track.dart';

// 遥控进度本地外推（docs/12 C-12 已知限制的补偿）：服务端校准 + 本地预测。
void main() {
  final t0 = DateTime(2026, 7, 19, 12);

  HMusicPlaybackState state({
    required PlaybackStatus status,
    required int positionMs,
    int durationMs = 200000,
    String trackId = 'tx:1',
  }) {
    return HMusicPlaybackState(
      sessionId: 'default',
      deviceId: 'xiaomi-speaker',
      state: status,
      track: HMusicTrack(
        id: trackId,
        source: 'tx',
        sourceTrackId: '1',
        title: '测试曲',
        artist: '测试歌手',
      ),
      positionMs: positionMs,
      durationMs: durationMs,
      volume: 50,
      playMode: PlayMode.listLoop,
      queueIndex: 0,
      queueLength: 1,
      seekEnabled: true,
      updatedAt: t0.millisecondsSinceEpoch,
    );
  }

  test('playing 时按本地时钟外推，paused 不外推', () {
    final projector = RemotePositionProjector();
    projector.sync(
      state(status: PlaybackStatus.playing, positionMs: 10000),
      t0,
    );
    expect(
      projector.estimate(t0.add(const Duration(milliseconds: 1200))),
      const Duration(milliseconds: 11200),
    );

    projector.sync(state(status: PlaybackStatus.paused, positionMs: 12000), t0);
    expect(
      projector.estimate(t0.add(const Duration(seconds: 30))),
      const Duration(milliseconds: 12000),
    );
  });

  test('外推按 durationMs 封顶', () {
    final projector = RemotePositionProjector();
    projector.sync(
      state(status: PlaybackStatus.playing, positionMs: 199000),
      t0,
    );
    expect(
      projector.estimate(t0.add(const Duration(seconds: 10))),
      const Duration(milliseconds: 200000),
    );
  });

  test('同曲连续播放中轮询小幅回跳（<2.5s）单调托底不回扫', () {
    final projector = RemotePositionProjector();
    projector.sync(
      state(status: PlaybackStatus.playing, positionMs: 10000),
      t0,
    );
    final t1 = t0.add(const Duration(seconds: 5));
    // 外推已到 15s，轮询回读 14s（延迟抖动）：不回扫，托底 15s 继续走。
    projector.sync(
      state(status: PlaybackStatus.playing, positionMs: 14000),
      t1,
    );
    expect(projector.estimate(t1), const Duration(milliseconds: 15000));
    // 托底只兜住起点，之后仍随基准 + 流逝时间推进。
    expect(
      projector.estimate(t1.add(const Duration(seconds: 2))),
      const Duration(milliseconds: 16000),
    );
  });

  test('seek 后退（>2.5s）立即贴齐服务端，不被托底顶住', () {
    final projector = RemotePositionProjector();
    projector.sync(
      state(status: PlaybackStatus.playing, positionMs: 60000),
      t0,
    );
    final t1 = t0.add(const Duration(seconds: 5));
    projector.sync(
      state(status: PlaybackStatus.playing, positionMs: 20000),
      t1,
    );
    expect(projector.estimate(t1), const Duration(milliseconds: 20000));
  });

  test('切歌重置基准，新曲从服务端值起算', () {
    final projector = RemotePositionProjector();
    projector.sync(
      state(status: PlaybackStatus.playing, positionMs: 180000),
      t0,
    );
    final t1 = t0.add(const Duration(seconds: 5));
    projector.sync(
      state(status: PlaybackStatus.playing, positionMs: 0, trackId: 'tx:2'),
      t1,
    );
    expect(projector.estimate(t1), Duration.zero);
  });
}
