/// 播放接口与能力对齐服务端型号表，固件的暂停/续播兼容规则保留在本机。
class MiHardwareProfile {
  MiHardwareProfile(String hardware, {Iterable<String> extraModels = const []})
    : _hardware = hardware.trim().toUpperCase(),
      _extraModels = extraModels.map((v) => v.trim().toUpperCase()).toSet();

  final String _hardware;
  final Set<String> _extraModels;

  static const _playMusicModels = <String>[
    'X08C',
    'X08E',
    'X8F',
    'X4B',
    'LX05',
    'OH2',
    'OH2P',
    'X6A',
    'LX04',
    'L05B',
    'L05C',
    'LX06',
    'L06A',
    'X08A',
    'X10A',
    'L15A',
    'L16A',
    'L17A',
  ];

  bool get needsPlayMusicApi =>
      _hardware.isNotEmpty &&
      (_playMusicModels.contains(_hardware) ||
          _extraModels.contains(_hardware));

  bool get needsFullReplayOnResume =>
      const ['OH2', 'OH2P', 'S12A'].contains(_hardware);

  bool get needsStopOnPause => _hardware == 'S12A';

  bool get supportsStartOffset => !needsFullReplayOnResume;

  bool get supportsSeek => !const ['OH2', 'OH2P'].contains(_hardware);

  bool get hasUnreliablePlayStatus =>
      const ['OH2', 'OH2P', 'S12A'].contains(_hardware);

  String get media => _hardware == 'S12A' ? 'app_android' : 'app_ios';

  String get playMethod =>
      needsPlayMusicApi ? 'player_play_music' : 'player_play_url';
}
