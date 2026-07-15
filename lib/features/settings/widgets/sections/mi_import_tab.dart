import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/hmusic_palette.dart';
import '../../../../shared/widgets/hmusic_card.dart';
import '../../view_models/mi_account_view_model.dart';
import 'settings_field.dart';

// 导入会话兜底通道：粘贴 STS 地址，或直接填 serviceToken + userId。对齐 web renderImportTab。
class MiImportTab extends ConsumerStatefulWidget {
  const MiImportTab({super.key});

  @override
  ConsumerState<MiImportTab> createState() => _MiImportTabState();
}

class _MiImportTabState extends ConsumerState<MiImportTab> {
  final TextEditingController _stsUrl = TextEditingController();
  final TextEditingController _token = TextEditingController();
  final TextEditingController _userId = TextEditingController();

  @override
  void dispose() {
    _stsUrl.dispose();
    _token.dispose();
    _userId.dispose();
    super.dispose();
  }

  void _import() {
    unawaited(
      ref
          .read(miAccountViewModelProvider.notifier)
          .importSession(
            stsUrl: _stsUrl.text,
            serviceToken: _token.text,
            userId: _userId.text,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = ref.watch(miAccountViewModelProvider);

    return HMusicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '兜底通道：粘贴验证完成后的 STS 地址，或直接填 serviceToken + userId。',
            style: TextStyle(fontSize: 12, color: palette.muted, height: 1.6),
          ),
          const SizedBox(height: 16),
          SettingsField(
            label: 'STS 地址',
            child: TextField(
              controller: _stsUrl,
              decoration: const InputDecoration(
                hintText: 'https://api2.mina.mi.com/sts?…',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('— 或 —', style: TextStyle(color: palette.muted)),
          ),
          const SizedBox(height: 12),
          SettingsField(
            label: 'serviceToken',
            child: TextField(controller: _token),
          ),
          const SizedBox(height: 16),
          SettingsField(
            label: 'userId',
            child: TextField(controller: _userId),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: state.busy ? null : _import,
              child: Text(state.busy ? '导入中…' : '导入会话'),
            ),
          ),
        ],
      ),
    );
  }
}
