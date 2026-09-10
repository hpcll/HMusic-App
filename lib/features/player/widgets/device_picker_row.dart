import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/platform/client_playback_capabilities.dart';
import '../../settings/models/hmusic_device.dart';
import '../view_models/device_picker_view_model.dart';

class DevicePickerRow extends ConsumerWidget {
  const DevicePickerRow({
    required this.device,
    required this.actingId,
    super.key,
  });

  final HMusicDevice device;
  final String actingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final acting = actingId == device.id;
    final local =
        device.id == HMusicPlaybackState.localDeviceId ||
        device.type == 'browser';
    final supported = ref
        .watch(clientPlaybackCapabilitiesProvider)
        .canSelectDevice(deviceId: device.id, deviceType: device.type);
    return ListTile(
      enabled: supported && actingId.isEmpty,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: SizedBox.square(
        dimension: 24,
        child: acting
            ? const CircularProgressIndicator(strokeWidth: 2)
            : Icon(
                device.isDefault
                    ? Icons.check_rounded
                    : local
                    ? Icons.devices_rounded
                    : Icons.speaker_rounded,
                size: 22,
              ),
      ),
      title: Text(device.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        !supported
            ? ClientPlaybackCapabilities.localPlaybackUnavailableReason
            : local
            ? '使用当前设备播放'
            : device.isOnline
            ? '在线'
            : device.type == 'xiaomi-direct'
            ? '未确认在线'
            : '离线',
        style: TextStyle(color: palette.muted, fontSize: 12.5),
      ),
      onTap: !supported || actingId.isNotEmpty
          ? null
          : () async {
              final ok = await ref
                  .read(devicePickerViewModelProvider.notifier)
                  .select(device);
              if (ok && context.mounted) Navigator.of(context).pop();
            },
    );
  }
}
