import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../core/platform/client_playback_capabilities.dart';
import '../../../../shared/widgets/hmusic_inline_notice.dart';
import '../../view_models/devices_view_model.dart';
import 'device_setting_item.dart';

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
    final capabilities = ref.watch(clientPlaybackCapabilitiesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 就地反馈：本节操作的结果/错误显示在顶部，不弹浮层。
        if (state.notice != null) ...<Widget>[
          HMusicInlineNotice(state.notice!),
          const SizedBox(height: 12),
        ],
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
            DeviceSettingItem(
              device: state.devices[i],
              busy: state.actingId.isNotEmpty,
              supported: capabilities.canSelectDevice(
                deviceId: state.devices[i].id,
                deviceType: state.devices[i].type,
              ),
              onSelect: () => notifier.select(state.devices[i]),
              onProbe: () => notifier.probe(state.devices[i]),
            ),
          ],
      ],
    );
  }
}
