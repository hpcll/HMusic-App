import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../auth/views/auth_page.dart';
import '../view_models/connection_view_model.dart';
import '../widgets/server_address_form.dart';

class ConnectionPage extends ConsumerStatefulWidget {
  const ConnectionPage({super.key});

  static const String path = '/connect';

  @override
  ConsumerState<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends ConsumerState<ConnectionPage> {
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(connectionViewModelProvider.notifier).loadSavedAddress(),
      ),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionViewModelProvider);
    ref.listen(connectionViewModelProvider, (previous, next) {
      if (_addressController.text.isEmpty && next.suggestedAddress.isNotEmpty) {
        _addressController.text = next.suggestedAddress;
      }
    });
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // 底边距大于顶边距：内容重心略高于几何中心（视觉居中），大窗不显下坠。
            padding: const EdgeInsets.fromLTRB(40, 48, 40, 96),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // 居中构图：品牌块（图标 + 衬线字标 + 副标题）与表单块拉开大段距离，
                // 分组呼吸感是这页的关键——间距均匀就会「挤成一坨」。
                Icon(
                  Icons.graphic_eq_rounded,
                  size: 40,
                  color: palette.textStrong,
                ),
                const SizedBox(height: 20),
                Text(
                  'HMusic',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  '连接运行在 NAS 或家庭服务器上的 HMusic Server',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: palette.mutedStrong),
                ),
                const SizedBox(height: 52),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: ServerAddressForm(
                    controller: _addressController,
                    isConnecting: state.isConnecting,
                    errorMessage: state.errorMessage,
                    onSubmit: _connect,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _connect() async {
    final success = await ref
        .read(connectionViewModelProvider.notifier)
        .connect(_addressController.text);
    if (success && mounted) context.go(AuthPage.path);
  }
}
