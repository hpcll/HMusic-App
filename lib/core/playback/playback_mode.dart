/// App 的播放后端。模式只描述数据与控制归属，不暴露具体实现。
enum PlaybackMode { server, direct, player }

extension PlaybackModeWire on PlaybackMode {
  String get wireName => switch (this) {
    PlaybackMode.server => 'server',
    PlaybackMode.direct => 'direct',
    PlaybackMode.player => 'player',
  };

  bool get usesLocalBackend => this != PlaybackMode.server;

  static PlaybackMode parse(String? value) => switch (value) {
    'direct' => PlaybackMode.direct,
    'player' => PlaybackMode.player,
    _ => PlaybackMode.server,
  };
}
