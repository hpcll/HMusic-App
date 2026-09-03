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

  // 需要登录时表单也不是一上来就在，而是问清楚状态、且页面转场落定后才淡入
  // ——观感是「字标（从连接页接过来的那个）先稳住，然后表单出现」。
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
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(AuthForm), findsOneWidget);
    expect(find.text('更换服务器'), findsOneWidget);
  });

  // 他的原话：「起码是等动画完成」。状态问得再快，表单也要等页面转场（450ms）
  // 落定才出现，不能砸在交叉淡入的中途。
  testWidgets('未登录且状态秒回：表单仍要等转场落定才出现', (tester) async {
    final router = _authRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _app(_FakeAuthRepository(authenticated: false), router),
    );

    // 状态已经问回来了（无 gate），但转场还没落定 → 表单不许出现。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AuthForm), findsNothing);

    // 过了 450ms 才轮到它。
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byType(AuthForm), findsOneWidget);
  });

  // 用户反馈：冷启动接续快进登录页那一下，「图标重了一下」。根因是这页把品牌
  // 块垂直居中，而连接页锚在视口 18%——两页 450ms 交叉淡出时，两个位置不同的
  // 字标一深一浅叠着。这页必须与连接页同一套几何（锚点 18%，夹 24~180）。
  testWidgets('品牌块锚在视口 18%，与连接页逐像素重合', (tester) async {
    final router = _authRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      _app(_FakeAuthRepository(authenticated: false), router),
    );
    await tester.pumpAndSettle();

    final double top = tester.getTopLeft(find.byType(BrandWordmark)).dy;
    final double expected = (600.0 * 0.18).clamp(24.0, 180.0);
    expect(top, moreOrLessEquals(expected, epsilon: 2));
  });
}
