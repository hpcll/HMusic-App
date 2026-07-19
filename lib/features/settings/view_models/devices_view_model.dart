import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/network/api_failure.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../data/api_devices_repository.dart';
import '../models/hmusic_device.dart';
import '../models/settings_section_states.dart';

final NotifierProvider<DevicesViewModel, DevicesState>
devicesViewModelProvider = NotifierProvider<DevicesViewModel, DevicesState>(
  DevicesViewModel.new,
);

class DevicesViewModel extends Notifier<DevicesState> {
  @override
  DevicesState build() => const DevicesState();

  Future<void> load() async {
    try {
      final devices = await ref.read(devicesRepositoryProvider).getDevices();
      state = state.copyWith(devices: devices, loaded: true);
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        loaded: true,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  Future<void> refresh() async {
    if (state.refreshing) return;
    state = state.copyWith(refreshing: true);
    try {
      final count = await ref.read(devicesRepositoryProvider).refresh();
      await load();
      state = state.copyWith(
        refreshing: false,
        notice: HMusicNotice.success('已刷新，共 $count 台设备'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        refreshing: false,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  Future<void> select(HMusicDevice device) async {
    if (state.actingId.isNotEmpty) return;
    state = state.copyWith(actingId: device.id);
    try {
      // select 返回切换后的播放状态（服务端同时暂停旧设备、更新 deviceId）。
      // 必须注入 AudioHandler，否则：1) 本机 player 不停继续播（双端出声）；
      // 2) AudioHandler._serverState 仍是旧 deviceId（UI 状态不刷新）。
      final playback = await ref
          .read(devicesRepositoryProvider)
          .select(device.id);
      final handler = await ref.read(hmusicAudioHandlerProvider.future);
      // autoplay: false，切设备不自动播放——只同步状态、停旧设备。
      // _applyServerState 内部会判断 deviceId：非本机则 stop player。
      await handler.applyRemotePlayback(playback, autoplay: false);
      await load();
      state = state.copyWith(
        notice: HMusicNotice.success('默认设备已切换为 ${device.name}'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    } finally {
      state = state.copyWith(actingId: '');
    }
  }

  Future<void> probe(HMusicDevice device) async {
    if (state.actingId.isNotEmpty) return;
    state = state.copyWith(actingId: device.id);
    try {
      await ref.read(devicesRepositoryProvider).probe(device.id);
      await load();
      state = state.copyWith(
        notice: HMusicNotice.success('${device.name} 探测完成'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    } finally {
      state = state.copyWith(actingId: '');
    }
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }
}
