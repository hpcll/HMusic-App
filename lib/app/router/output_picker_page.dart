import 'package:flutter/material.dart';

import '../../features/player/widgets/device_picker_sheet.dart';

// 原生输出 intent 进入同一个 Flutter 设备列表；模态路由负责返回与 chrome 显隐。
class OutputPickerPage extends Page<void> {
  const OutputPickerPage({super.key});

  @override
  Route<void> createRoute(BuildContext context) => ModalBottomSheetRoute<void>(
    settings: this,
    builder: (_) => const DevicePickerSheet(),
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
  );
}
