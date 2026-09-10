import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/app/router/routed_mi_web_verifier.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/core/direct/auth/mi_web_cookie_bridge.dart';
import 'package:hmusic/core/direct/auth/mi_web_verifier.dart';
import 'package:hmusic/core/direct/mi_direct_providers.dart';
import 'package:hmusic/features/direct_auth/data/direct_verification_driver.dart';
import 'package:hmusic/features/direct_auth/view_models/direct_verification_view_model.dart';
import 'package:hmusic/features/direct_auth/views/direct_verification_page.dart';

class ObservedVerification extends DirectVerificationViewModel {
  ObservedVerification(super.request);
  final controller = Completer<InAppWebViewController>();
  final loadedPages = StreamController<Uri>.broadcast();

  @override
  Future<void> attach(DirectVerificationDriver driver) {
    if (!controller.isCompleted) {
      controller.complete((driver as InAppVerificationDriver).controller);
    }
    return super.attach(driver);
  }

  @override
  Future<void> loaded(Uri? uri) async {
    await super.loaded(uri);
    if (uri != null && uri.scheme != 'about' && !loadedPages.isClosed) {
      loadedPages.add(uri);
    }
  }
}

class VerificationHarness {
  VerificationHarness() {
    container = ProviderContainer(
      overrides: [
        miWebCookiesProvider.overrideWithValue(cookies),
        directVerificationViewModelProvider.overrideWith2((request) {
          final vm = ObservedVerification(request);
          pages.add(vm);
          return vm;
        }),
      ],
    );
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('HMusic 验证返回测试'))),
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
  }

  final cookies = MiWebCookieBridge();
  final pages = <ObservedVerification>[];
  late final ProviderContainer container;
  late final GoRouter router;
  late final RoutedMiWebVerifier verifier;

  Widget get app => UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router, theme: HMusicTheme.light()),
  );

  Future<void> dispose() async {
    router.dispose();
    container.dispose();
    for (final page in pages) {
      await page.loadedPages.close();
    }
  }
}

/// 原生事件可在两帧之间到达；持续推进 Flutter 帧，确保路由退出和 Cookie 清理完成。
Future<T> pumpUntil<T>(
  WidgetTester tester,
  Future<T> future, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  var done = false;
  T? value;
  Object? error;
  StackTrace? stack;
  unawaited(
    future.then<void>(
      (result) {
        value = result;
        done = true;
      },
      onError: (Object failure, StackTrace trace) {
        error = failure;
        stack = trace;
        done = true;
      },
    ),
  );
  final deadline = DateTime.now().add(timeout);
  while (!done && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (!done) {
    throw TimeoutException('Native verification did not complete', timeout);
  }
  if (error != null) Error.throwWithStackTrace(error!, stack!);
  return value as T;
}
