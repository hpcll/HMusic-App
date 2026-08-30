import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/brand_mark.dart';
import '../../charts/views/charts_page.dart';
import '../../connection/views/connection_page.dart';
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

  // 品牌渐显的时长；表单要等它走完才出现，不和开场抢戏。用计时器而不是动画的
  // onEnd 作准：onEnd 万一不触发，登录表单就永远出不来，那是死锁。
  static const Duration _introDuration = Duration(milliseconds: 520);
  Timer? _introTimer;
  bool _introDone = false;

  @override
  void initState() {
    super.initState();
    _introTimer = Timer(_introDuration, () {
      if (mounted) setState(() => _introDone = true);
    });
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
    _introTimer?.cancel();
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
    final palette = context.palette;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // 状态问清楚之前只留品牌：接续成功的用户根本不该看见登录页，问都没问就把
    // 表单摆出来，就是他反馈的「还是闪一下登录页」。确认没登录、且品牌渐显走完
    // 之后表单才淡入——首次打开的顺序是「字标浮上来，然后表单出现」。
    final showForm = state.needsSignIn && (_introDone || reduceMotion);
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
                // 品牌块渐显，与连接页同一条曲线同一段时长：两页的字标位置、尺寸
                // 完全一致，配上路由的淡入淡出，整段开场里字标看着是定在原地的。
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: reduceMotion ? Duration.zero : _introDuration,
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 10),
                      child: child,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // 与连接页同款居中构图：品牌块与表单块拉开大段距离，两页读作
                      // 一个家族。完整字标（字形含 H + Music 连读），不再另写
                      // "HMusic" 文字——图形与文字各报一遍 H 是之前「不协调」的病根。
                      const BrandWordmark(size: 56),
                      const SizedBox(height: 20),
                      Text(
                        // 常态用品牌 slogan（与连接页同一句同一声调，两页读作一个
                        // 家族）；首次建号是关键指令，保留说明文案。
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
                    ],
                  ),
                ),
                const SizedBox(height: 52),
                AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: showForm
                      ? Column(
                          key: const ValueKey<String>('form'),
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 380),
                              child: AuthForm(
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
                              onPressed: () =>
                                  context.go(ConnectionPage.switchPath),
                              child: const Text('更换服务器'),
                            ),
                          ],
                        )
                      : Padding(
                          key: const ValueKey<String>('checking'),
                          padding: const EdgeInsets.only(top: 8),
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: _showSpinner ? 1 : 0,
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 260),
                              curve: Curves.easeOut,
                              child: const CircularProgressIndicator(),
                            ),
                          ),
                        ),
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
