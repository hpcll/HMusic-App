import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';

class ServerAddressForm extends StatelessWidget {
  const ServerAddressForm({
    required this.controller,
    required this.isConnecting,
    required this.onSubmit,
    this.focusNode,
    this.errorMessage,
    super.key,
  });

  // 表单纵向几何。键盘让位量由这些数字算出（见 build 里的 scrollPadding），
  // 改间距/按钮高只改这里，让位跟着走。
  static const double _fieldContentPadding = 15;
  static const double _errorGap = 14;
  static const double _errorLineHeight = 18;
  static const double _buttonGap = 28;
  static const double _buttonHeight = 48;

  // 让位目标：连接按钮下缘落在键盘上缘之上 16。再多就是「推太高」。
  static const double _keyboardClearance = 16;

  final TextEditingController controller;

  // 外置焦点：页面层靠它感知输入框聚焦来驱动注脚让位（见 _ConnectionPageState）。
  final FocusNode? focusNode;

  final bool isConnecting;
  final String? errorMessage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // 键盘让位走 Flutter 的标准机制：Scaffold 随键盘逐帧收缩 body，
    // EditableText 在每一帧把光标矩形滚进视口。scrollPadding 把这块「必须
    // 露出的矩形」从光标下缘一路扩到连接按钮下缘再留一口气，输入框和按钮
    // 就一起抬到键盘上方；扩多少按本表单的几何算，不猜。
    final double revealBelowCaret =
        _fieldContentPadding +
        (errorMessage == null ? 0 : _errorGap + _errorLineHeight) +
        _buttonGap +
        _buttonHeight +
        _keyboardClearance;
    // 外置小标签 + 灰底无描边圆角输入框（主题默认 filled）：外置标签是 web
    // 表单的成品形态，软胶囊输入款是全站柔化后的统一表单材质。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '服务器地址',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: palette.mutedStrong,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: !isConnecting,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          scrollPadding: EdgeInsets.fromLTRB(20, 20, 20, revealBelowCaret),
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.10:6650',
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: _fieldContentPadding,
            ),
          ),
          onSubmitted: (_) => onSubmit(),
        ),
        if (errorMessage != null) ...<Widget>[
          const SizedBox(height: _errorGap),
          Text(
            errorMessage!,
            style: TextStyle(
              fontSize: 13,
              height: _errorLineHeight / 13,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: _buttonGap),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(_buttonHeight),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          onPressed: isConnecting ? null : onSubmit,
          child: Text(isConnecting ? '正在连接…' : '连接服务器'),
        ),
      ],
    );
  }
}
