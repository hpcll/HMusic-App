import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/direct_login_view_model.dart';

class DirectCredentialsForm extends ConsumerStatefulWidget {
  const DirectCredentialsForm({super.key});

  @override
  ConsumerState<DirectCredentialsForm> createState() =>
      _DirectCredentialsFormState();
}

class _DirectCredentialsFormState extends ConsumerState<DirectCredentialsForm> {
  final _userId = TextEditingController();
  final _token = TextEditingController();
  bool _usePassToken = false;

  @override
  void dispose() {
    _userId.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier = ref.read(directLoginViewModelProvider.notifier);
    if (_usePassToken) {
      await notifier.importPassToken(
        userId: _userId.text,
        passToken: _token.text,
      );
    } else {
      await notifier.importSession(
        userId: _userId.text,
        serviceToken: _token.text,
      );
    }
    if (mounted && ref.read(directLoginViewModelProvider).account != null) {
      _token.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(directLoginViewModelProvider.select((s) => s.busy));
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('使用已有的小米凭据'),
      children: [
        const Text('仅导入你自己的小米账号凭据。导入后会验证设备访问权限，再保存到本机安全存储。'),
        const SizedBox(height: 16),
        DropdownButtonFormField<bool>(
          initialValue: _usePassToken,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '凭据类型'),
          items: const [
            DropdownMenuItem(value: false, child: Text('micoapi serviceToken')),
            DropdownMenuItem(value: true, child: Text('passToken')),
          ],
          onChanged: busy
              ? null
              : (value) => setState(() {
                  _usePassToken = value ?? false;
                  _token.clear();
                }),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _userId,
          enabled: !busy,
          decoration: const InputDecoration(labelText: '小米 userId'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _token,
          enabled: !busy,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: _usePassToken ? 'passToken' : 'serviceToken',
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: busy ? null : _submit,
          child: const Text('验证并导入'),
        ),
      ],
    );
  }
}
