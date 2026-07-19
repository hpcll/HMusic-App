import 'dart:async';

import 'models/hmusic_playback_state.dart';
import 'playback_repository.dart';

// 远端设备（音箱）前台轮询：服务端的音箱状态回读与「自然播完自动连播」都挂在
// GET /playback/state 的 refresh-on-read 上（docs/12 §2），没人轮询音箱播完
// 一首就停、遥控 UI 永远陈旧。播放目标为远端时每 5s 拉一次权威状态；本机播放
// 不轮询（真相源是 just_audio + 周期回写）。
class RemoteStatePoller {
  RemoteStatePoller({
    required PlaybackRepository repository,
    required void Function(HMusicPlaybackState state) onState,
    Duration interval = const Duration(seconds: 5),
  }) : _repository = repository,
       _onState = onState,
       _interval = interval;

  final PlaybackRepository _repository;
  final void Function(HMusicPlaybackState state) _onState;
  final Duration _interval;

  Timer? _timer;
  bool _inFlight = false;

  // 每次服务端状态落地后由 handler 喂入：远端启动轮询，回到本机即停。
  // deviceId 为空 = 冷状态还没有播放目标（全新 Server 从未播放）：没有远端
  // 可轮询，不空转。
  void sync(HMusicPlaybackState state) {
    if (state.deviceId == null || state.isLocalDevice) {
      stop();
    } else {
      _timer ??= Timer.periodic(_interval, (_) => unawaited(_poll()));
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      _onState(await _repository.getState());
    } catch (_) {
      // 轮询尽力而为：失败退避到下一周期（断网/凭据暂不可用）。
    } finally {
      _inFlight = false;
    }
  }
}
