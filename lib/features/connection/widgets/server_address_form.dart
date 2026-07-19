import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';

class ServerAddressForm extends StatelessWidget {
  const ServerAddressForm({
    required this.controller,
    required this.isConnecting,
    required this.onSubmit,
    this.errorMessage,
    super.key,
  });

  final TextEditingController controller;
  final bool isConnecting;
  final String? errorMessage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
          enabled: !isConnecting,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.10:8090',
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          ),
          onSubmitted: (_) => onSubmit(),
        ),
        if (errorMessage != null) ...<Widget>[
          const SizedBox(height: 14),
          Text(
            errorMessage!,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 28),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
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
