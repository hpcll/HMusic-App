import '../../../core/audio/models/hmusic_playback_state.dart';
import 'hmusic_device.dart';
import 'server_config.dart';

// M4-1 五个简单子页的小状态类。都是「数据 + busy + notice」三件套，
// 单独成文件过碎，聚在一起（同属设置子页状态，互不引用）。

class DevicesState {
  const DevicesState({
    this.devices = const <HMusicDevice>[],
    this.loaded = false,
    this.refreshing = false,
    this.actingId = '',
    this.notice,
  });

  final List<HMusicDevice> devices;
  final bool loaded;
  final bool refreshing;

  // 正在 select/probe 的设备 id，防连点。
  final String actingId;
  final String? notice;

  DevicesState copyWith({
    List<HMusicDevice>? devices,
    bool? loaded,
    bool? refreshing,
    String? actingId,
    String? notice,
    bool clearNotice = false,
  }) {
    return DevicesState(
      devices: devices ?? this.devices,
      loaded: loaded ?? this.loaded,
      refreshing: refreshing ?? this.refreshing,
      actingId: actingId ?? this.actingId,
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

class ConfigFormState {
  const ConfigFormState({this.config, this.saving = false, this.notice});

  final ServerConfig? config;
  final bool saving;
  final String? notice;

  ConfigFormState copyWith({
    ServerConfig? config,
    bool? saving,
    String? notice,
    bool clearNotice = false,
  }) {
    return ConfigFormState(
      config: config ?? this.config,
      saving: saving ?? this.saving,
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

class DiagState {
  const DiagState({this.playback, this.busyKind = '', this.notice});

  final HMusicPlaybackState? playback;

  // ''|'tone'|'tts'，对齐 web busy。
  final String busyKind;
  final String? notice;

  DiagState copyWith({
    HMusicPlaybackState? playback,
    String? busyKind,
    String? notice,
    bool clearNotice = false,
  }) {
    return DiagState(
      playback: playback ?? this.playback,
      busyKind: busyKind ?? this.busyKind,
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

class SecurityState {
  const SecurityState({this.changing = false, this.notice});

  final bool changing;
  final String? notice;

  SecurityState copyWith({
    bool? changing,
    String? notice,
    bool clearNotice = false,
  }) {
    return SecurityState(
      changing: changing ?? this.changing,
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

class TracksState {
  const TracksState({
    this.tracks = const <ManualTrack>[],
    this.loaded = false,
    this.busy = false,
    this.notice,
  });

  final List<ManualTrack> tracks;
  final bool loaded;
  final bool busy;
  final String? notice;

  TracksState copyWith({
    List<ManualTrack>? tracks,
    bool? loaded,
    bool? busy,
    String? notice,
    bool clearNotice = false,
  }) {
    return TracksState(
      tracks: tracks ?? this.tracks,
      loaded: loaded ?? this.loaded,
      busy: busy ?? this.busy,
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}
