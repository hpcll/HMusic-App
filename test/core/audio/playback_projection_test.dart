import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/audio/playback_projection.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:just_audio/just_audio.dart';

const HMusicTrack _track = HMusicTrack(
  id: 'tx:9',
  source: 'tx',
  sourceTrackId: '9',
  title: '七里香',
  artist: '周杰伦',
  album: '七里香',
  durationMs: 269000,
  coverUrl: 'https://example.com/cover.jpg',
);

HMusicPlaybackState _state({
  String? deviceId = 'local-browser',
  PlaybackStatus state = PlaybackStatus.playing,
  int positionMs = 1000,
}) => HMusicPlaybackState(
  sessionId: 'default',
  state: state,
  positionMs: positionMs,
  durationMs: 269000,
  volume: 60,
  playMode: PlayMode.listLoop,
  queueIndex: 3,
  queueLength: 10,
  seekEnabled: true,
  updatedAt: 0,
  deviceId: deviceId,
);

void main() {
  group('mediaItemForTrack', () {
    test('maps id/title/artist/album/duration and source extras', () {
      final item = mediaItemForTrack(_track);
      expect(item.id, 'tx:9');
      expect(item.title, '七里香');
      expect(item.artist, '周杰伦');
      expect(item.album, '七里香');
      expect(item.duration, const Duration(milliseconds: 269000));
      expect(item.artUri, Uri.parse('https://example.com/cover.jpg'));
      expect(item.extras!['source'], 'tx');
      expect(item.extras!['sourceTrackId'], '9');
      // 禁止把凭据或签名 URL 泄漏进 MediaItem extras。
      expect(item.extras!.containsKey('token'), isFalse);
    });

    test('omits artUri and duration when track lacks them', () {
      const track = HMusicTrack(
        id: 'tx:1',
        source: 'tx',
        sourceTrackId: '1',
        title: '无封面',
        artist: '歌手',
      );
      final item = mediaItemForTrack(track);
      expect(item.artUri, isNull);
      expect(item.duration, isNull);
    });
  });

  group('audioProcessingStateFor', () {
    test('maps every just_audio ProcessingState', () {
      expect(
        audioProcessingStateFor(ProcessingState.idle),
        AudioProcessingState.idle,
      );
      expect(
        audioProcessingStateFor(ProcessingState.loading),
        AudioProcessingState.loading,
      );
      expect(
        audioProcessingStateFor(ProcessingState.buffering),
        AudioProcessingState.buffering,
      );
      expect(
        audioProcessingStateFor(ProcessingState.ready),
        AudioProcessingState.ready,
      );
      expect(
        audioProcessingStateFor(ProcessingState.completed),
        AudioProcessingState.completed,
      );
    });
  });

  group('playbackStateProjection', () {
    test('exposes fixed controls and queueIndex from server state', () {
      // 用一个不触发 platform channel 的伪 player 壳：playbackStateProjection 只读
      // processingState/playing/position/bufferedPosition/speed，全部经 getter；
      // 用 _FakeAudioPlayer 避免在单测里实例化真实 AudioSession。
      final player = _FakeAudioPlayer();
      final projected = playbackStateProjection(
        player: player,
        serverState: _state(),
      );
      expect(projected.controls, contains(MediaControl.stop));
      expect(projected.systemActions, contains(MediaAction.seek));
      expect(projected.queueIndex, 3);
    });

    test('queueIndex is null when no server state is available', () {
      final projected = playbackStateProjection(
        player: _FakeAudioPlayer(),
        serverState: null,
      );
      expect(projected.queueIndex, isNull);
    });

    // 远端设备（音箱）：本机 player 恒 stopped，playing/position 必须取服务端
    // 权威状态，否则遥控模式按钮永远显示「已暂停 0:00」。
    test('远端在播：playing/position 取服务端，不看本机 player', () {
      final projected = playbackStateProjection(
        player: _FakeAudioPlayer(), // playing=false, position=0
        serverState: _state(deviceId: 'speaker-1', positionMs: 123000),
      );
      expect(projected.playing, isTrue);
      expect(projected.updatePosition, const Duration(milliseconds: 123000));
      expect(projected.processingState, AudioProcessingState.ready);
      expect(projected.speed, 1.0);
      expect(projected.queueIndex, 3);
    });

    test('远端暂停：speed 0，锁屏进度不在两次轮询间自行外推', () {
      final projected = playbackStateProjection(
        player: _FakeAudioPlayer(),
        serverState: _state(
          deviceId: 'speaker-1',
          state: PlaybackStatus.paused,
        ),
      );
      expect(projected.playing, isFalse);
      expect(projected.speed, 0.0);
      expect(projected.processingState, AudioProcessingState.ready);
    });

    test('远端停止：processingState 收敛 idle', () {
      final projected = playbackStateProjection(
        player: _FakeAudioPlayer(),
        serverState: _state(
          deviceId: 'speaker-1',
          state: PlaybackStatus.stopped,
        ),
      );
      expect(projected.playing, isFalse);
      expect(projected.processingState, AudioProcessingState.idle);
    });
  });
}

class _FakeAudioPlayer implements AudioPlayer {
  @override
  ProcessingState get processingState => ProcessingState.ready;

  @override
  bool get playing => false;

  @override
  Duration get position => Duration.zero;

  @override
  Duration get bufferedPosition => Duration.zero;

  @override
  double get speed => 1.0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
