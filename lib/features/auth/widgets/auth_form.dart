import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';

class AuthForm extends StatelessWidget {
  const AuthForm({
    required this.usernameController,
    required this.passwordController,
    required this.isSetup,
    required this.isBusy,
    required this.onSubmit,
    this.errorMessage,
    super.key,
  });

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool isSetup;
  final bool isBusy;
  final String? errorMessage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // 外置小标签 + 灰底无描边圆角输入框（主题默认 filled）：外置标签是 web
    // 表单的成品形态，软胶囊输入款是全站柔化后的统一表单材质。
    const contentPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 15);
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: palette.mutedStrong,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('用户名', style: labelStyle),
        const SizedBox(height: 8),
        TextField(
          controller: usernameController,
          enabled: !isBusy,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.username],
          decoration: const InputDecoration(contentPadding: contentPadding),
        ),
        const SizedBox(height: 20),
        Text('密码', style: labelStyle),
        const SizedBox(height: 8),
        TextField(
          controller: passwordController,
          enabled: !isBusy,
          obscureText: true,
          textInputAction: TextInputAction.done,
          autofillHints: <String>[
            isSetup ? AutofillHints.newPassword : AutofillHints.password,
          ],
          decoration: const InputDecoration(contentPadding: contentPadding),
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
          onPressed: isBusy ? null : onSubmit,
          child: Text(
            isBusy
                ? '处理中…'
                : isSetup
                ? '创建并登录'
                : '登录',
          ),
        ),
      ],
    );
  }
}
