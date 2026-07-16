import 'dart:ui';

import 'package:flutter/material.dart';

// docs/03 模态规格：遮罩 rgba(0,0,0,.42) + blur(2px)，点遮罩关闭；
// 卡片主体保持不透明（dialogTheme 的 panel 底），玻璃只在 barrier 层。
// 全站弹窗统一走这里，别再直接 showDialog。
Future<T?> showHMusicDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x6B000000),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, animation, secondaryAnimation) =>
        SafeArea(child: builder(context)),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final t = Curves.easeOut.transform(animation.value);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2 * t, sigmaY: 2 * t),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}
