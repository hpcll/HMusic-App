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

  // 表单要等页面转场（连接页 → 这一页是 450ms 的淡入淡出）落定才出现，不在
  // 交叉淡入的中途冒出来。品牌块本身不做动画，见 build 里的说明。
  static const Duration _formDelay = Duration(milliseconds: 450);
  Timer? _formTimer;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _formTimer = Timer(_formDelay, () {
      if (mounted) setState(() => _settled = true);
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
    _formTimer?.cancel();
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
    // 表单摆出来，就是他反馈的「还是闪一下登录页」。确认没登录、且转场落定之后
    // 表单才淡入——顺序是「字标（从上一页接过来的那个）稳住，然后表单出现」。
    final showForm = state.needsSignIn && (_settled || reduceMotion);
    // 键盘免疫的视口高度（Scaffold 之上量）：锚点以此为基准。用 viewPadding
    // 而不是 padding——键盘弹出时 padding.bottom 会被清零，viewPadding 恒定；
    // 键盘弹起时 body 被 Scaffold 收缩，若锚点跟着 body 高度走，表单聚焦
    // 那一刻整列会突然上移一截。
    final double viewportHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewPaddingOf(context).vertical;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        // 与连接页逐像素同一套几何：品牌锚在视口 18%（夹 24~180）、横向
        // 40 留白、最多 380 宽。两页是 450ms 交叉淡入淡出，字标位置一致时
        // 读作同一个字标定在原地；上一版这里用 Center 垂直居中，字标比
        // 连接页低了一大截，转场途中两个字标一深一浅叠着——就是"进登录
        // 页之前图标重叠一下"的来源。开场动画只属于连接页，这页只接住它。
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double anchorTop = (viewportHeight * 0.18).clamp(24.0, 180.0);
            return SingleChildScrollView(
              // 底边距大于顶边距：内容重心略高（视觉居中），与连接页一致。
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, anchorTop, 0, 96),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const BrandWordmark(size: BrandWordmark.standardSize),
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
                                      constraints: const BoxConstraints(
                                        maxWidth: 380,
                                      ),
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
          },
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
