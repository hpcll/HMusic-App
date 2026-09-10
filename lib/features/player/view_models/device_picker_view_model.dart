import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/platform/client_playback_capabilities.dart';
import '../../../core/playback/backend_request.dart';
import '../../settings/data/api_devices_repository.dart';
import '../../settings/models/hmusic_device.dart';

// 播放页设备选择 sheet 的最小状态：只做「列出 + 选中」，刷新/探测仍归设置页。
// 跨 feature 只引 settings 的 data/models（与 favorites → playlists 同款准入）。
class DevicePickerState {
  const DevicePickerState({
    this.devices = const <HMusicDevice>[],
    this.loading = false,
    this.actingId = '',
    this.error,
  });

  final List<HMusicDevice> devices;
  final bool loading;
  final String actingId;
  final String? error;

  DevicePickerState copyWith({
    List<HMusicDevice>? devices,
    bool? loading,
    String? actingId,
    String? error,
    bool clearError = false,
  }) => DevicePickerState(
    devices: devices ?? this.devices,
    loading: loading ?? this.loading,
    actingId: actingId ?? this.actingId,
    error: clearError ? null : error ?? this.error,
  );
}

final NotifierProvider<DevicePickerViewModel, DevicePickerState>
devicePickerViewModelProvider =
    NotifierProvider<DevicePickerViewModel, DevicePickerState>(
      DevicePickerViewModel.new,
    );

class DevicePickerViewModel extends Notifier<DevicePickerState> {
  @override
  DevicePickerState build() {
    ref.watch(devicesRepositoryProvider);
    return const DevicePickerState();
  }

  Future<void> load() async {
    final request = BackendRequest(ref);
    state = state.copyWith(loading: true, clearError: true);
    try {
      final devices = await ref.read(devicesRepositoryProvider).getDevices();
      if (!request.current) return;
      state = state.copyWith(devices: devices, loading: false);
    } on ApiFailure catch (failure) {
      if (!request.current) return;
      state = state.copyWith(loading: false, error: failure.message);
    }
  }

  // 与设置页 select 同语义：服务端切默认设备并返回切换后的播放状态，注入
  // AudioHandler（停旧设备、同步 UI，autoplay: false 不自动开播）。
  // 成功返回 true，由 sheet 自行关闭。
  Future<bool> select(HMusicDevice device) async {
    final request = BackendRequest(ref);
    if (state.actingId.isNotEmpty) return false;
    if (!ref
        .read(clientPlaybackCapabilitiesProvider)
        .canSelectDevice(deviceId: device.id, deviceType: device.type)) {
      state = state.copyWith(
        error: ClientPlaybackCapabilities.localPlaybackUnavailableReason,
      );
      return false;
    }
    state = state.copyWith(actingId: device.id, clearError: true);
    try {
      final repository = ref.read(devicesRepositoryProvider);
      final handler = await ref.read(hmusicAudioHandlerProvider.future);
      request.requireCurrent();
      await handler.executePlayback(() {
        request.requireCurrent();
        return repository.select(device.id);
      }, autoplay: false);
      return request.current;
    } on ApiFailure catch (failure) {
      if (!request.current) return false;
      state = state.copyWith(error: failure.message);
      return false;
    } finally {
      if (request.current) state = state.copyWith(actingId: '');
    }
  }
}
