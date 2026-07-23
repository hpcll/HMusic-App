import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/hmusic_palette.dart';
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
          const Divider(height: 40),
          _DeleteAccountRow(deleting: state.deleting),
        ],
      ),
    );
  }
}

// 删除账户（App Store 合规入口）：危险操作，红色文案 + 二次确认（需输入密码）。
// 删除后服务端物理清除全部数据并回未初始化态，本端清会话回登录/setup。
class _DeleteAccountRow extends ConsumerWidget {
  const _DeleteAccountRow({required this.deleting});

  final bool deleting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final danger = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '删除账户',
          style: TextStyle(fontWeight: FontWeight.w600, color: danger),
        ),
        const SizedBox(height: 6),
        Text(
          '永久删除账户及服务器上的全部数据（歌单、播放历史、下载文件、小米登录），'
          '不可恢复。服务器将回到未初始化状态。',
          style: TextStyle(fontSize: 12.5, color: context.palette.muted),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: deleting
                ? null
                : () => unawaited(_confirm(context, ref)),
            style: OutlinedButton.styleFrom(
              foregroundColor: danger,
              side: BorderSide(color: danger.withValues(alpha: 0.5)),
            ),
            child: Text(deleting ? '删除中…' : '删除账户'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final danger = Theme.of(context).colorScheme.error;
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除账户'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('此操作不可恢复。输入当前密码以确认。'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: '当前密码'),
              onSubmitted: (v) => Navigator.of(context).pop(v),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            style: TextButton.styleFrom(foregroundColor: danger),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (password == null || password.isEmpty) return;
    await ref
        .read(securityViewModelProvider.notifier)
        .deleteAccount(password: password);
  }
}
