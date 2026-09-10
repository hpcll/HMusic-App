import 'package:flutter/material.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../core/audio/models/hmusic_playback_state.dart';
import '../../../../core/platform/client_playback_capabilities.dart';
import '../../../../shared/widgets/state_dot.dart';
import '../../models/hmusic_device.dart';

// 设备行，对齐 .device-item：1px 边框卡，默认设备 text-strong 边 + panel-2 底。
class DeviceSettingItem extends StatelessWidget {
  const DeviceSettingItem({
    required this.device,
    required this.busy,
    required this.onSelect,
    required this.onProbe,
    required this.supported,
    super.key,
  });

  final HMusicDevice device;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onProbe;
  final bool supported;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = device.isDefault;
    final local =
        device.id == HMusicPlaybackState.localDeviceId ||
        device.type == 'browser';
    return Material(
      color: active ? palette.panelSecondary : palette.panel,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: active ? palette.textStrong : palette.line),
      ),
      child: InkWell(
        onTap: busy || !supported ? null : onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          child: Row(
            children: <Widget>[
              // 在线=青绿点（设备正在线上，属「正在发生的事」），离线=muted。
              StateDot(
                device.isOnline ? PlaybackStatus.playing : PlaybackStatus.idle,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: palette.text),
                    ),
                    Text(
                      !supported
                          ? ClientPlaybackCapabilities
                                .localPlaybackUnavailableReason
                          : local
                          ? '使用当前设备播放'
                          : device.isOnline
                          ? '在线'
                          : device.type == 'xiaomi-direct'
                          ? '未确认在线'
                          : '离线',
                      style: TextStyle(fontSize: 12, color: palette.muted),
                    ),
                  ],
                ),
              ),
              if (active) ...<Widget>[
                const SizedBox(width: 6),
                _badge(palette),
              ],
              // 虚拟设备（本机播放）没有可探测的硬件能力。
              if (!local) ...<Widget>[
                const SizedBox(width: 6),
                TextButton(
                  onPressed: busy ? null : onProbe,
                  child: const Text('探测'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(HMusicPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: palette.textStrong),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '默认',
        style: TextStyle(fontSize: 11, color: palette.textStrong),
      ),
    );
  }
}
