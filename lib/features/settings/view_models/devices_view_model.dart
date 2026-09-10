import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/platform/client_playback_capabilities.dart';
import '../../../core/playback/backend_request.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../data/api_devices_repository.dart';
import '../models/hmusic_device.dart';
import '../models/settings_section_states.dart';
import 'settings_menu_view_model.dart';

final NotifierProvider<DevicesViewModel, DevicesState>
devicesViewModelProvider = NotifierProvider<DevicesViewModel, DevicesState>(
  DevicesViewModel.new,
);

class DevicesViewModel extends Notifier<DevicesState> {
  @override
  DevicesState build() {
    ref.watch(devicesRepositoryProvider);
    return const DevicesState();
  }

  // 切默认/刷新设备后重拉设置页左栏摘要（「播放设备」标签），宽屏布局下
  // 摘要不随子页动作自动刷新。尽力而为：刷不动不影响主流程。
  void _refreshMenuSummary() {
    try {
      unawaited(
        ref
            .read(settingsMenuViewModelProvider.notifier)
            .loadSummary()
            .catchError((Object _) {}),
      );
    } catch (_) {}
  }

  Future<void> load() async {
    final request = BackendRequest(ref);
    try {
      final devices = await ref.read(devicesRepositoryProvider).getDevices();
      if (!request.current) return;
      state = state.copyWith(devices: devices, loaded: true);
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(
        loaded: true,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  Future<void> refresh() async {
    final request = BackendRequest(ref);
    if (state.refreshing) return;
    state = state.copyWith(refreshing: true);
    try {
      final count = await ref.read(devicesRepositoryProvider).refresh();
      if (!request.current) return;
      await load();
      if (!request.current) return;
      _refreshMenuSummary();
      state = state.copyWith(
        refreshing: false,
        notice: HMusicNotice.success('已刷新，共 $count 台设备'),
      );
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(
        refreshing: false,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  Future<void> select(HMusicDevice device) async {
    final request = BackendRequest(ref);
    if (state.actingId.isNotEmpty) return;
    if (!ref
        .read(clientPlaybackCapabilitiesProvider)
        .canSelectDevice(deviceId: device.id, deviceType: device.type)) {
      state = state.copyWith(
        notice: const HMusicNotice.error(
          ClientPlaybackCapabilities.localPlaybackUnavailableReason,
        ),
      );
      return;
    }
    state = state.copyWith(actingId: device.id);
    try {
      // select 返回切换后的播放状态（服务端同时暂停旧设备、更新 deviceId）。
      // 必须注入 AudioHandler，否则：1) 本机 player 不停继续播（双端出声）；
      // 2) AudioHandler._serverState 仍是旧 deviceId（UI 状态不刷新）。
      final repository = ref.read(devicesRepositoryProvider);
      final handler = await ref.read(hmusicAudioHandlerProvider.future);
      // autoplay: false，切设备不自动播放——只同步状态、停旧设备。
      // _applyServerState 内部会判断 deviceId：非本机则 stop player。
      request.requireCurrent();
      await handler.executePlayback(() {
        request.requireCurrent();
        return repository.select(device.id);
      }, autoplay: false);
      if (!request.current) return;
      await load();
      if (!request.current) return;
      _refreshMenuSummary();
      state = state.copyWith(
        notice: HMusicNotice.success('默认设备已切换为 ${device.name}'),
      );
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    } finally {
      if (request.current) state = state.copyWith(actingId: '');
    }
  }

  Future<void> probe(HMusicDevice device) async {
    final request = BackendRequest(ref);
    if (state.actingId.isNotEmpty) return;
    state = state.copyWith(actingId: device.id);
    try {
      await ref.read(devicesRepositoryProvider).probe(device.id);
      if (!request.current) return;
      await load();
      if (!request.current) return;
      state = state.copyWith(
        notice: HMusicNotice.success('${device.name} 探测完成'),
      );
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    } finally {
      if (request.current) state = state.copyWith(actingId: '');
    }
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }
}
