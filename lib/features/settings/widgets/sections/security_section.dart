import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/hmusic_card.dart';
import '../../view_models/security_view_model.dart';
import 'settings_field.dart';

// 修改密码子页：成功后服务端换发的新 token 已由 repository 落盘，无需重登。
class SecuritySectionView extends ConsumerStatefulWidget {
  const SecuritySectionView({super.key});

  @override
  ConsumerState<SecuritySectionView> createState() =>
      _SecuritySectionViewState();
}

class _SecuritySectionViewState extends ConsumerState<SecuritySectionView> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();

  // 按钮可用性跟随输入：controller 变化不触发 provider，用本地重建。
  void _onChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _current.addListener(_onChanged);
    _next.addListener(_onChanged);
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(securityViewModelProvider.notifier)
        .change(currentPassword: _current.text, newPassword: _next.text);
    if (ok && mounted) {
      _current.clear();
      _next.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(securityViewModelProvider);
    final canSubmit =
        !state.changing && _current.text.isNotEmpty && _next.text.isNotEmpty;

    return HMusicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SettingsField(
            label: '当前密码',
            child: TextField(
              controller: _current,
              obscureText: true,
              autofillHints: const <String>[AutofillHints.password],
            ),
          ),
          const SizedBox(height: 16),
          SettingsField(
            label: '新密码（至少 8 位）',
            child: TextField(
              controller: _next,
              obscureText: true,
              autofillHints: const <String>[AutofillHints.newPassword],
              onSubmitted: (_) => unawaited(_submit()),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: canSubmit ? () => unawaited(_submit()) : null,
              child: Text(state.changing ? '修改中…' : '修改密码'),
            ),
          ),
        ],
      ),
    );
  }
}
