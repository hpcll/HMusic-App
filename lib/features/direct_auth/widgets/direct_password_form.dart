import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/direct/auth/mi_passport_result.dart';
import '../view_models/direct_login_view_model.dart';
import 'direct_captcha_image.dart';

class DirectPasswordForm extends ConsumerStatefulWidget {
  const DirectPasswordForm({super.key});

  @override
  ConsumerState<DirectPasswordForm> createState() => _DirectPasswordFormState();
}

class _DirectPasswordFormState extends ConsumerState<DirectPasswordForm> {
  final _account = TextEditingController();
  final _password = TextEditingController();
  final _captcha = TextEditingController();

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    _captcha.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = ref.read(directLoginViewModelProvider);
    await ref
        .read(directLoginViewModelProvider.notifier)
        .login(
          account: _account.text,
          password: _password.text,
          captchaCode: state.challenge?.kind == MiChallengeKind.captcha
              ? _captcha.text
              : null,
        );
    if (mounted && ref.read(directLoginViewModelProvider).account != null) {
      _password.clear();
      _captcha.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(directLoginViewModelProvider);
    final notifier = ref.read(directLoginViewModelProvider.notifier);
    ref.listen(directLoginViewModelProvider, (previous, next) {
      if (next.account != null) {
        _password.clear();
        _captcha.clear();
      }
      if (next.captchaImage != null &&
          previous?.captchaImage != next.captchaImage) {
        _captcha.clear();
      }
    });
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _account,
            enabled: !state.busy,
            autofillHints: const [AutofillHints.username],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '小米账号',
              hintText: '手机号、邮箱或小米 ID',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            enabled: !state.busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            onSubmitted: state.busy ? null : (_) => _submit(),
            decoration: const InputDecoration(labelText: '密码'),
          ),
          if (state.challenge?.kind == MiChallengeKind.captcha) ...[
            const SizedBox(height: 16),
            DirectCaptchaImage(bytes: state.captchaImage, loading: state.busy),
            TextButton(
              onPressed: state.busy ? null : notifier.refreshCaptcha,
              child: const Text('换一张验证码'),
            ),
            TextField(
              controller: _captcha,
              enabled: !state.busy,
              autocorrect: false,
              onSubmitted: state.busy ? null : (_) => _submit(),
              decoration: const InputDecoration(labelText: '图片验证码'),
            ),
          ],
          if (state.challenge?.kind == MiChallengeKind.identity) ...[
            const SizedBox(height: 16),
            const Text('请在 App 内完成小米登录或验证，完成后会自动返回并登录。'),
            OutlinedButton(
              onPressed: state.busy
                  ? null
                  : () => notifier.openVerification(
                      account: _account.text,
                      password: _password.text,
                    ),
              child: const Text('打开小米验证页面'),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: state.busy ? null : _submit,
            child: Text(state.busy ? '正在登录…' : '登录小米账号'),
          ),
        ],
      ),
    );
  }
}
