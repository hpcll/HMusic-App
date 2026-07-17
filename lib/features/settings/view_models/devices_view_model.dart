import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      await ref.read(devicesRepositoryProvider).select(device.id);
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
