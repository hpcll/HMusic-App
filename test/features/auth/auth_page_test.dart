import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/features/auth/data/api_auth_repository.dart';
import 'package:hmusic/features/auth/data/auth_repository.dart';
import 'package:hmusic/features/auth/models/auth_session.dart';
import 'package:hmusic/features/auth/models/auth_status.dart';
import 'package:hmusic/features/auth/models/auth_user.dart';
import 'package:hmusic/features/auth/views/auth_page.dart';
import 'package:hmusic/features/auth/widgets/auth_form.dart';
import 'package:hmusic/features/charts/views/charts_page.dart';
import 'package:hmusic/shared/widgets/brand_mark.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.authenticated, this.gate});

  final bool authenticated;

  // 状态探测挂起：复刻「还没问到结果」的那段时间窗，用来验这期间页面长什么样。
  final Future<void>? gate;

  @override
  Future<AuthStatus> status() async {
    if (gate != null) await gate;
    return AuthStatus(
      initialized: true,
      authenticated: authenticated,
      user: authenticated ? const AuthUser(id: '1', username: 'pc') : null,
    );
  }

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthSession> setup({
    required String username,
    required String password,
  }) => throw UnimplementedError();
}

Widget _app(_FakeAuthRepository repository, GoRouter router) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(repository)],
  child: MaterialApp.router(routerConfig: router),
);

GoRouter _authRouter() => GoRouter(
  initialLocation: AuthPage.path,
  routes: <RouteBase>[
    GoRoute(path: AuthPage.path, builder: (context, state) => const AuthPage()),
    GoRoute(
      path: ChartsPage.path,
      builder: (context, state) =>
          const Scaffold(body: Text('charts destination')),
    ),
  ],
);

void main() {
  // 用户反馈：开场动画加上之后，冷启动仍然「闪一下登录页」。根因是 AuthViewState
  // 的 status 初值是 idle 而不是 loadingStatus——首帧就把用户名密码框渲染出来了，
  // 之后才去问服务端。已登录的用户于是先被闪一下登录页再跳首页。
  testWidgets('已登录：全程不出现登录表单，直接进首页', (tester) async {
    final Completer<void> gate = Completer<void>();
    final router = _authRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _app(_FakeAuthRepository(authenticated: true, gate: gate.future), router),
    );

    // 状态还没问到：只有品牌，表单和「更换服务器」都不许露面。
    expect(find.byType(BrandWordmark), findsOneWidget);
    expect(find.byType(AuthForm), findsNothing);
    expect(find.text('更换服务器'), findsNothing);

    gate.complete();
    await tester.pump(); // 状态落地这一帧：已登录，表单依然不该出现
    expect(find.byType(AuthForm), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('charts destination'), findsOneWidget);
    expect(find.byType(AuthForm), findsNothing);
  });

  // 需要登录时表单也不是一上来就在，而是问清楚状态后才淡入——首次打开的观感是
  // 「品牌浮上来，然后表单出现」，不是一屏控件砸脸。
  testWidgets('未登录：状态问清楚后表单才出现', (tester) async {
    final Completer<void> gate = Completer<void>();
    final router = _authRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _app(
        _FakeAuthRepository(authenticated: false, gate: gate.future),
        router,
      ),
    );

    expect(find.byType(AuthForm), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(AuthForm), findsOneWidget);
    expect(find.text('更换服务器'), findsOneWidget);
  });

  // 他的原话：「如果第一次打开 那也是动画完成再显示登录页」。状态问得再快，
  // 表单也要等品牌渐显（520ms）走完才出现，不能砸在动画中途。
  testWidgets('未登录且状态秒回：表单仍要等品牌渐显走完才出现', (tester) async {
    final router = _authRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _app(_FakeAuthRepository(authenticated: false), router),
    );

    // 状态已经问回来了（无 gate），但渐显还没走完 → 表单不许出现。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AuthForm), findsNothing);

    // 过了 520ms 才轮到它。
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pumpAndSettle();
    expect(find.byType(AuthForm), findsOneWidget);
  });
}
