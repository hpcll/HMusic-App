import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/app/router/routed_mi_web_verifier.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/core/direct/auth/mi_web_verifier.dart';
import 'package:hmusic/core/direct/mi_direct_providers.dart';
import 'package:hmusic/features/direct_auth/view_models/direct_verification_view_model.dart';
import 'package:hmusic/features/direct_auth/views/direct_verification_page.dart';

import 'support/verification_fakes.dart';
import 'support/verification_webview_platform.dart';

void main() {
  final login = Uri.parse('https://account.xiaomi.com/fe/service/login');
  late ProviderContainer container;
  late GoRouter router;
  late RoutedMiWebVerifier verifier;
  late FakeVerificationCookies cookies;
  late VerificationWebViewPlatform platform;

  setUp(() {
    platform = VerificationWebViewPlatform();
    InAppWebViewPlatform.instance = platform;
    cookies = FakeVerificationCookies();
    container = ProviderContainer(
      overrides: [miWebCookiesProvider.overrideWithValue(cookies)],
    );
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('小米登录')),
        ),
        GoRoute(
          path: DirectVerificationPage.path,
          pageBuilder: (_, state) => NoTransitionPage<MiWebAuthResult>(
            key: state.pageKey,
            child: DirectVerificationPage(
              request: state.extra! as MiWebAuthRequest,
            ),
          ),
        ),
      ],
    );
    verifier = RoutedMiWebVerifier(() => router, cookies: cookies);
  });
  tearDown(() {
    router.dispose();
    container.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: HMusicTheme.light(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets(
    'plain App title and full-size embedded content return a typed result',
    (tester) async {
      await pumpApp(tester);
      final pending = verifier.open(url: login, cookies: []);
      await frames(tester);
      final request = router.state.extra! as MiWebAuthRequest;
      final vm = container.read(
        directVerificationViewModelProvider(request).notifier,
      );
      await vm.attach(FakeVerificationDriver());
      await vm.loaded(login);
      await tester.pumpAndSettle();
      expect(find.text('小米账号验证'), findsOneWidget);
      expect(find.byTooltip('关闭验证'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('web-content'))).height,
        greaterThan(300),
      );
      cookies.accountValues = {'userId': '123', 'passToken': 'fixture'};
      await vm.navigate(
        Uri.parse('https://api2.mina.mi.com/sts?ticket=fixture'),
        mainFrame: true,
      );
      await frames(tester);
      expect((await pending)?.accountCookies['userId'], '123');
      expect(cookies.clears, 1);
      expect(find.text('小米登录'), findsOneWidget);
      expect(find.byType(InAppWebView), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'close button cancels verification and releases the next attempt',
    (tester) async {
      await pumpApp(tester);
      final first = verifier.open(url: login, cookies: []);
      await frames(tester);
      await tester.tap(find.byTooltip('关闭验证'));
      await frames(tester);
      expect(await first, isNull);
      expect(cookies.clears, 1);
      final next = verifier.open(url: login, cookies: []);
      final cancelling = verifier.cancel();
      await frames(tester);
      await cancelling;
      expect(await next, isNull);
      expect(cookies.clears, 2);
      expect(platform.creations, 1);
    },
  );

  testWidgets('system back cancels and retry remains usable with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    final pending = verifier.open(url: login, cookies: []);
    await frames(tester);
    final request = router.state.extra! as MiWebAuthRequest;
    final vm = container.read(
      directVerificationViewModelProvider(request).notifier,
    );
    final driver = FakeVerificationDriver();
    await vm.attach(driver);
    vm.failed();
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '重新加载'));
    await vm.loaded(login);
    await tester.pumpAndSettle();
    expect(driver.reloads, 1);
    await tester.binding.handlePopRoute();
    await frames(tester);
    expect(await pending, isNull);
    expect(find.text('小米登录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
