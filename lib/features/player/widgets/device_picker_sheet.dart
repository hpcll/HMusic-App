import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../view_models/device_picker_view_model.dart';
import 'device_picker_row.dart';

// 播放设备选择 sheet（对齐 Apple Music 输出按钮的位置逻辑）：从播放页音量行尾
// 输出钮/设备状态行唤起，纯列表点选即切换（服务端停旧起新是现成语义）。
// 临时浮层属 chrome，后续可玻璃化；先用主题暖纸底保持克制。
Future<void> showDevicePickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: const DevicePickerSheet(),
    ),
  );
}

class DevicePickerSheet extends ConsumerStatefulWidget {
  const DevicePickerSheet({super.key});

  @override
  ConsumerState<DevicePickerSheet> createState() => _DevicePickerSheetState();
}

class _DevicePickerSheetState extends ConsumerState<DevicePickerSheet> {
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

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
            child: Text('播放设备', style: Theme.of(context).textTheme.titleMedium),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
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
                    _DevicePickerEmptyState(
                      message: state.error ?? '没有可用设备',
                      onRetry: state.loading
                          ? null
                          : () => ref
                                .read(devicePickerViewModelProvider.notifier)
                                .load(),
                    )
                  else ...<Widget>[
                    for (final device in state.devices)
                      DevicePickerRow(device: device, actingId: state.actingId),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DevicePickerEmptyState extends StatelessWidget {
  const _DevicePickerEmptyState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(message, style: TextStyle(color: context.palette.muted)),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重新扫描'),
            ),
          ),
        ],
      ),
    );
  }
}
