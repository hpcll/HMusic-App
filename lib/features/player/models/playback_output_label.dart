import '../../../core/audio/models/hmusic_playback_state.dart';

// Flutter 播放条与原生壳使用相同的输出名称；同曲切换设备也要刷新。
String playbackOutputLabel(HMusicPlaybackState? state) {
  if (state?.isLocalDevice ?? false) return '本机播放';
  final name = state?.deviceName?.trim();
  if (name != null && name.isNotEmpty) return name;
  return state?.deviceId?.isNotEmpty ?? false ? '音箱' : '未选择设备';
}

String playbackStatusLabel(HMusicPlaybackState state) => switch (state.state) {
  PlaybackStatus.playing => '正在播放',
  PlaybackStatus.paused => '已暂停',
  PlaybackStatus.loading => '加载中',
  PlaybackStatus.error => '播放出错',
  _ => '未在播放',
};
