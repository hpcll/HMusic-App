import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/brand_mark.dart';
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
                // 居中构图：品牌块（完整字标 + 副标题）与表单块拉开大段距离，
                // 分组呼吸感是这页的关键——间距均匀就会「挤成一坨」。
                // 字标本身含 H（字形双竖笔）+ Music 连读，不再另写 "HMusic"。
                const BrandWordmark(size: 56),
                const SizedBox(height: 20),
                // 副标题是品牌 slogan：一句轻轻的搭话，不解释产品、不重复品牌名。
                // 衬线 + 加宽字距 = 扉页题句的声调；mutedStrong 保证可读但不抢字标。
                Text(
                  '今天想听点什么',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NotoSerifSC',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    letterSpacing: 3,
                    color: palette.mutedStrong,
                  ),
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
