import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../core/audio/models/hmusic_playback_state.dart';
import '../../../../shared/widgets/state_dot.dart';
import '../../models/hmusic_device.dart';
import '../../view_models/devices_view_model.dart';

// 播放设备子页：刷新 + 设备列表（点选默认 / 探测）。对齐 web DevicesSection。
class DevicesSectionView extends ConsumerStatefulWidget {
  const DevicesSectionView({super.key});

  @override
  ConsumerState<DevicesSectionView> createState() => _DevicesSectionViewState();
}

class _DevicesSectionViewState extends ConsumerState<DevicesSectionView> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(devicesViewModelProvider.notifier).load(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = ref.watch(devicesViewModelProvider);
    final notifier = ref.read(devicesViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: state.refreshing ? null : notifier.refresh,
            child: Text(state.refreshing ? '刷新中…' : '从小米账号刷新设备'),
          ),
        ),
        const SizedBox(height: 16),
        if (!state.loaded)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Center(
              child: Text('加载中…', style: TextStyle(color: palette.muted)),
            ),
          )
        else if (state.devices.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Center(
              child: Text(
                '暂无设备，请先登录小米账号后刷新',
                style: TextStyle(color: palette.muted),
              ),
            ),
          )
        else
          for (var i = 0; i < state.devices.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 8),
            _DeviceItem(
              device: state.devices[i],
              busy: state.actingId.isNotEmpty,
              onSelect: () => notifier.select(state.devices[i]),
              onProbe: () => notifier.probe(state.devices[i]),
            ),
          ],
      ],
    );
  }
}

// 设备行，对齐 .device-item：1px 边框卡，默认设备 text-strong 边 + panel-2 底。
class _DeviceItem extends StatelessWidget {
  const _DeviceItem({
    required this.device,
    required this.busy,
    required this.onSelect,
    required this.onProbe,
  });

  final HMusicDevice device;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onProbe;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = device.isDefault;
    return Material(
      color: active ? palette.panelSecondary : palette.panel,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: active ? palette.textStrong : palette.line),
      ),
      child: InkWell(
        onTap: busy ? null : onSelect,
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
                    if ((device.type ?? '').isNotEmpty)
                      Text(
                        device.type!,
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
              if (device.type != 'browser') ...<Widget>[
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
