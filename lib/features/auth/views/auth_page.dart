import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../charts/views/charts_page.dart';
import '../../connection/views/connection_page.dart';
import '../models/auth_view_state.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/auth_form.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  static const String path = '/auth';

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(authViewModelProvider.notifier).loadStatus(),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authViewModelProvider);
    ref.listen(authViewModelProvider, (previous, next) {
      if (next.isAuthenticated) context.go(ChartsPage.path);
    });
    final isLoadingStatus = state.status == AuthSubmissionStatus.loadingStatus;
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // 底边距大于顶边距：内容重心略高于几何中心（视觉居中），与连接页一致。
            padding: const EdgeInsets.fromLTRB(40, 48, 40, 96),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // 与连接页同款居中构图：品牌块与表单块拉开大段距离，两页读作一个家族。
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
                  state.initialized ? '登录你的 HMusic Server' : '首次使用，请创建管理员账号',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: palette.mutedStrong),
                ),
                const SizedBox(height: 52),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: isLoadingStatus
                      ? const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : AuthForm(
                          usernameController: _usernameController,
                          passwordController: _passwordController,
                          isSetup: !state.initialized,
                          isBusy: state.isBusy,
                          errorMessage: state.errorMessage,
                          onSubmit: _submit,
                        ),
                ),
                const SizedBox(height: 18),
                // 静默出口：登错服务器时能回到连接页换地址，不困死在登录页。
                TextButton(
                  onPressed: () => context.go(ConnectionPage.path),
                  child: const Text('更换服务器'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    await ref
        .read(authViewModelProvider.notifier)
        .submit(
          username: _usernameController.text,
          password: _passwordController.text,
        );
  }
}
