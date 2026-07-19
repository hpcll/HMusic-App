import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/network/api_failure.dart';
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

// 实时进度流：统一采样 handler.effectivePosition（本机 just_audio 真值 /
// 远端本地外推），200ms 与 just_audio positionStream 粒度一致。远端也走这条流，
// 进度条和歌词染色平滑推进，不再随 5s 轮询按段步进。
final StreamProvider<Duration> livePositionProvider = StreamProvider<Duration>((
  ref,
) async* {
  final handler = await ref.watch(hmusicAudioHandlerProvider.future);
  yield handler.effectivePosition;
  yield* Stream<Duration>.periodic(
    const Duration(milliseconds: 200),
    (_) => handler.effectivePosition,
  );
});

// 进度真相源按播放目标分流已收敛进 handler.effectivePosition；
// 进度条/歌词行都从这一个口子取，禁止各页自行判断。
Duration playbackPositionOf(WidgetRef ref, HMusicPlaybackState state) {
  final live = ref.watch(livePositionProvider);
  return live.maybeWhen(
    data: (value) => value,
    orElse: () => Duration(milliseconds: state.positionMs),
  );
}

class PlayerViewModel {
  const PlayerViewModel(this._ref);

  final Ref _ref;

  Future<HMusicAudioHandler> get _handler =>
      _ref.read(hmusicAudioHandlerProvider.future);

  // 播放页/mini player 的播控回调都是 fire-and-forget（按钮不 await）：失败
  // 必须在这里兜住并走全局通知流弹 toast，否则遥控模式音箱失联、会话过期时
  // 点了毫无反应。PlaybackLoadException 在 handler 内已报过通知，不二次打扰。
  Future<void> _run(
    Future<void> Function(HMusicAudioHandler handler) command,
  ) async {
    final handler = await _handler;
    try {
      await command(handler);
    } on ApiFailure catch (failure) {
      handler.reportNotice(failure.message);
    } on PlaybackLoadException {
      // 装载失败已由 handler 的通知流报过。
    }
  }

  Future<void> play() => _run((handler) => handler.play());

  Future<void> pause() => _run((handler) => handler.pause());

  Future<void> seek(Duration position) =>
      _run((handler) => handler.seek(position));

  Future<void> skipToNext() => _run((handler) => handler.skipToNext());

  Future<void> skipToPrevious() => _run((handler) => handler.skipToPrevious());

  Future<void> setPlayMode(PlayMode mode) =>
      _run((handler) => handler.setPlayMode(mode));

  // 本机音量不走网络，失败面为零，保持直通。
  Future<void> setLocalVolume(double volume) async =>
      (await _handler).setLocalVolume(volume);

  // 远端设备（音箱）音量 0-100：经服务端下发设备指令，与本机音量严格分流。
  Future<void> setDeviceVolume(int volume) =>
      _run((handler) => handler.setDeviceVolume(volume));

  Future<double> readLocalVolume() async => (await _handler).player.volume;
}
