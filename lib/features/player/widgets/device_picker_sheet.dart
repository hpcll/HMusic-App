import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../settings/models/hmusic_device.dart';
import '../view_models/device_picker_view_model.dart';

// 播放设备选择 sheet（对齐 Apple Music 输出按钮的位置逻辑）：从播放页音量行尾
// 输出钮/设备状态行唤起，纯列表点选即切换（服务端停旧起新是现成语义）。
// 临时浮层属 chrome，后续可玻璃化；先用主题暖纸底保持克制。
Future<void> showDevicePickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _DevicePickerSheet(),
  );
}

class _DevicePickerSheet extends ConsumerStatefulWidget {
  const _DevicePickerSheet();

  @override
  ConsumerState<_DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends ConsumerState<_DevicePickerSheet> {
  @override
  void initState() {
    super.initState();
    // initState 内不能同步改 provider，延到帧后加载。
    unawaited(
      Future<void>.microtask(
        () => ref.read(devicePickerViewModelProvider.notifier).load(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(devicePickerViewModelProvider);
    final palette = context.palette;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
            child: Text('播放设备', style: Theme.of(context).textTheme.titleMedium),
          ),
          if (state.loading && state.devices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else if (state.devices.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Text(
                state.error ?? '没有可用设备',
                style: TextStyle(color: palette.muted),
              ),
            )
          else ...<Widget>[
            for (final device in state.devices)
              _DeviceRow(device: device, actingId: state.actingId),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
                child: Text(
                  state.error!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DeviceRow extends ConsumerWidget {
  const _DeviceRow({required this.device, required this.actingId});

  final HMusicDevice device;
  final String actingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final acting = actingId == device.id;
    // 本机虚拟设备恒可用；音箱离线仍可点（切换失败会如实报错）。
    final dimmed = !device.isOnline && device.type != 'browser';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      visualDensity: VisualDensity.compact,
      leading: SizedBox.square(
        dimension: 22,
        child: acting
            ? const Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : device.isDefault
            ? Icon(Icons.check_rounded, size: 20, color: palette.textStrong)
            : null,
      ),
      title: Text(
        device.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: dimmed ? palette.muted : palette.textStrong),
      ),
      trailing: Text(
        device.type == 'browser'
            ? '本机'
            : device.isOnline
            ? '在线'
            : '离线',
        style: TextStyle(fontSize: 12.5, color: palette.muted),
      ),
      onTap: acting
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
