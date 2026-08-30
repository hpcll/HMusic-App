import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/brand_mark.dart';
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

  // 读登录状态慢了才转菊花。冷启动接续成功后会路过这一页，token 有效时它只停留
  // 一两百毫秒就跳首页——那一闪的菊花正好夹在连接页和首页之间，开 App 的观感
  // 就是「闪了两下才进去」。门槛内不出声，品牌块在整段开场里看着是定住的。
  static const Duration _spinnerDelay = Duration(milliseconds: 700);
  Timer? _spinnerTimer;
  bool _showSpinner = false;

  @override
  void initState() {
    super.initState();
    _spinnerTimer = Timer(_spinnerDelay, () {
      if (mounted) setState(() => _showSpinner = true);
    });
    unawaited(
      Future<void>.microtask(
        () => ref.read(authViewModelProvider.notifier).loadStatus(),
      ),
    );
  }

  @override
  void dispose() {
    _spinnerTimer?.cancel();
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
                // 完整字标（字形含 H + Music 连读），不再另写 "HMusic" 文字——
                // 图形与文字各报一遍 H 是之前「不协调」的病根。
                const BrandWordmark(size: 56),
                const SizedBox(height: 20),
                Text(
                  // 常态用品牌 slogan（与连接页同一句同一声调，两页读作一个家族）；
                  // 首次建号是关键指令，保留说明文案。
                  state.initialized ? '今天想听点什么' : '首次使用，请创建管理员账号',
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
                  child: isLoadingStatus
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: _showSpinner ? 1 : 0,
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 260),
                              curve: Curves.easeOut,
                              child: const CircularProgressIndicator(),
                            ),
                          ),
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
                  onPressed: () => context.go(ConnectionPage.switchPath),
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
