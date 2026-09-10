/// App 的播放后端。模式只描述数据与控制归属，不暴露具体实现。
enum PlaybackMode { server, direct }

extension PlaybackModeWire on PlaybackMode {
  String get wireName => switch (this) {
    PlaybackMode.server => 'server',
    PlaybackMode.direct => 'direct',
  };

  static PlaybackMode parse(String? value) => switch (value) {
    'direct' => PlaybackMode.direct,
    _ => PlaybackMode.server,
  };
}
