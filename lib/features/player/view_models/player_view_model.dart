import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../shared/models/hmusic_notice.dart';

final Provider<PlayerViewModel> playerViewModelProvider =
    Provider<PlayerViewModel>((ref) {
      return PlayerViewModel(ref);
    });

// 服务端权威播放状态流：播放页/mini player 订阅它渲染封面、曲目、模式、队列指针。
final StreamProvider<HMusicPlaybackState> serverPlaybackStateProvider =
    StreamProvider<HMusicPlaybackState>((ref) async* {
      final handler = await ref.watch(hmusicAudioHandlerProvider.future);
      final current = handler.serverState;
      if (current != null) {
        yield current;
      } else {
        // 冷启动无缓存状态：主动拉一次，否则流永不产出、订阅方无限 loading。
        // 拉取失败异常自然冒出 → StreamProvider 错误态（播放页渲染错误，不卡转圈）。
        await handler.ensureServerState();
        final fetched = handler.serverState;
        if (fetched != null) yield fetched;
      }
      yield* handler.serverStateStream;
    });

// 播放链路自身的失败通知（自动切歌撞死链、resume 无源可播等）：这些路径没有
// 前台点播 VM 捕获，壳层 ref.listen 本 provider 统一弹错误 toast。
// HMusicNotice 刻意无 ==，重复文案也会再次触发监听。
final StreamProvider<HMusicNotice> playbackNoticeProvider =
    StreamProvider<HMusicNotice>((ref) async* {
      final handler = await ref.watch(hmusicAudioHandlerProvider.future);
      yield* handler.playbackNoticeStream.map(HMusicNotice.error);
    });

// 本机实时进度：just_audio 的 position（约每 200ms），播放页进度条平滑靠它，
// 不用服务端每 3 秒的回写值（会一跳一跳）。
final StreamProvider<Duration> livePositionProvider = StreamProvider<Duration>((
  ref,
) async* {
  final handler = await ref.watch(hmusicAudioHandlerProvider.future);
  yield handler.player.position;
  yield* handler.player.positionStream;
});

class PlayerViewModel {
  const PlayerViewModel(this._ref);

  final Ref _ref;

  Future<HMusicAudioHandler> get _handler =>
      _ref.read(hmusicAudioHandlerProvider.future);

  Future<void> play() async => (await _handler).play();

  Future<void> pause() async => (await _handler).pause();

  Future<void> seek(Duration position) async => (await _handler).seek(position);

  Future<void> skipToNext() async => (await _handler).skipToNext();

  Future<void> skipToPrevious() async => (await _handler).skipToPrevious();

  Future<void> setPlayMode(PlayMode mode) async =>
      (await _handler).setPlayMode(mode);

  Future<void> setLocalVolume(double volume) async =>
      (await _handler).setLocalVolume(volume);

  Future<double> readLocalVolume() async => (await _handler).player.volume;
}
