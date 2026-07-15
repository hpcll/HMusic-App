import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/hmusic_card.dart';
import '../../view_models/mi_account_view_model.dart';
import 'settings_field.dart';

// 账号密码 + 短信通道：账号/密码/图形验证码登录；服务端要短信时下方弹短信挑战卡。
// 表单值由本地 controller 持有，登录/确认调 VM 方法。
class MiPasswordTab extends ConsumerStatefulWidget {
  const MiPasswordTab({super.key});

  @override
  ConsumerState<MiPasswordTab> createState() => _MiPasswordTabState();
}

class _MiPasswordTabState extends ConsumerState<MiPasswordTab> {
  final TextEditingController _account = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _captcha = TextEditingController();
  final TextEditingController _smsCode = TextEditingController();

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    _captcha.dispose();
    _smsCode.dispose();
    super.dispose();
  }

  void _login() {
    unawaited(
      ref
          .read(miAccountViewModelProvider.notifier)
          .loginPassword(
            account: _account.text,
            password: _password.text,
            captcha: _captcha.text,
          ),
    );
  }

  void _confirm() {
    unawaited(
      ref.read(miAccountViewModelProvider.notifier).confirmSms(_smsCode.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(miAccountViewModelProvider);
    final notifier = ref.read(miAccountViewModelProvider.notifier);
    final challenge = state.challenge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        HMusicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SettingsField(
                label: '小米账号（手机号 / 邮箱）',
                child: TextField(controller: _account),
              ),
              const SizedBox(height: 16),
              SettingsField(
                label: '密码',
                child: TextField(controller: _password, obscureText: true),
              ),
              const SizedBox(height: 16),
              SettingsField(
                label: '图形验证码（仅提示需要时填写）',
                child: TextField(controller: _captcha),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: state.busy ? null : _login,
                  child: Text(state.busy ? '登录中…' : '登录小米账号'),
                ),
              ),
            ],
          ),
        ),
        if (challenge != null) ...<Widget>[
          const SizedBox(height: 16),
          _SmsCard(
            maskedPhone: challenge.maskedPhone ?? '绑定手机',
            controller: _smsCode,
            busy: state.busy,
            onConfirm: _confirm,
            onResend: notifier.resendSms,
            onCancel: notifier.cancelChallenge,
          ),
        ],
      ],
    );
  }
}

// 短信挑战卡，对齐 web .sms-card：text-strong 描边 + 验证码输入 + 确认/重发/重登。
class _SmsCard extends StatelessWidget {
  const _SmsCard({
    required this.maskedPhone,
    required this.controller,
    required this.busy,
    required this.onConfirm,
    required this.onResend,
    required this.onCancel,
  });

  final String maskedPhone;
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onResend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return HMusicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SettingsCardTitle('验证码已发至 $maskedPhone'),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(hintText: '短信验证码'),
                  onSubmitted: (_) => onConfirm(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: busy ? null : onConfirm,
                child: const Text('确认验证'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextButton(onPressed: onResend, child: const Text('重新发送')),
              TextButton(onPressed: onCancel, child: const Text('重新登录')),
            ],
          ),
        ],
      ),
    );
  }
}
