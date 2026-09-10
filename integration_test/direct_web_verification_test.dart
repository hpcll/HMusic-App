import 'dart:async';
import 'dart:io' as io;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/auth/mi_web_auth_policy.dart';
import 'package:hmusic/core/direct/auth/mi_web_login_prefill.dart';
import 'package:integration_test/integration_test.dart';

import 'support/native_test_report.dart';
import 'support/verification_harness.dart';
import 'support/verification_prefill_cases.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const report = NativeTestReport('direct-web-verification');
  final details = <String, Object?>{'presentation': 'embedded-flutter-page'};
  unawaited(
    binding.allTestsPassed.future.then(
      (passed) => report.write(passed ? 'passed' : 'failed', {
        ...details,
        'failures': binding.failureMethodsDetails
            .map((f) => f.toString())
            .toList(),
      }),
    ),
  );

  testWidgets('embedded Xiaomi page hands credentials back through the App route', (
    tester,
  ) async {
    await report.write('started', details);
    final harness = VerificationHarness();
    addTearDown(harness.dispose);
    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();
    final url = Uri.parse(
      'https://account.xiaomi.com/pass/serviceLogin?sid=micoapi',
    );
    final prefill = MiWebLoginPrefill(
      account: prefillFixtureAccount,
      password: prefillFixturePassword,
    );
    final result = harness.verifier.open(
      url: url,
      cookies: [],
      prefill: prefill,
    );
    await tester.pump();
    await tester.pump();
    final page = harness.pages.single;
    final loaded = page.loadedPages.stream.first;
    final controller = await pumpUntil(tester, page.controller.future);
    final actual = await pumpUntil(
      tester,
      loaded,
      timeout: const Duration(seconds: 45),
    );
    expect(actual.host, 'account.xiaomi.com');
    expect(find.text('小米账号验证'), findsOneWidget);
    expect(find.byTooltip('关闭验证'), findsOneWidget);
    expect(find.byType(InAppWebView), findsOneWidget);
    expect(
      await controller.evaluateJavascript(
        source: 'document.body.innerText.length',
      ),
      isA<num>().having(
        (length) => length,
        'visible page text',
        greaterThan(0),
      ),
    );
    expect(
      await controller.evaluateJavascript(source: 'navigator.userAgent'),
      MiWebAuthPolicy.userAgent,
    );
    details['publicPageLoadedInsideApp'] = true;
    await tester.pumpAndSettle();
    final screenshot = await binding.takeScreenshot('direct-verification-page');
    await io.File(
      '${NativeTestReport.outputDirectory}/hmusic-direct-verification-page.png',
    ).writeAsBytes(screenshot, flush: true);
    await verifyPublicPrefill(controller);
    expect(prefill.isEmpty, isTrue);
    details['publicLoginFormPrefilledWithoutSubmitting'] = true;
    await report.write('running', {...details, 'phase': 'callback-fixture'});

    await verifyPrefillFixtures(tester, page, controller);
    details['delayedPrefillAndUserEditsPreserved'] = true;
    details['foreignOriginPrefillBlocked'] = true;
    // 只用本地 HTML 和临时测试 Cookie 验证交接，不提交账号或验证码。
    final localLoaded = page.loadedPages.stream.first;
    await controller.loadData(
      data:
          '<!doctype html><meta name="viewport" content="width=device-width"><p>HMusic callback fixture</p>',
      baseUrl: WebUri('https://account.xiaomi.com/hmusic-verification-fixture'),
    );
    await pumpUntil(tester, localLoaded);
    final cookies = CookieManager.instance();
    for (final entry in {
      'userId': 'fixture-user',
      'passToken': 'fixture-pass',
    }.entries) {
      expect(
        await cookies.setCookie(
          url: WebUri('https://account.xiaomi.com/'),
          name: entry.key,
          value: entry.value,
          path: '/',
          isSecure: true,
          isHttpOnly: true,
        ),
        isTrue,
      );
    }
    expect(
      await controller.evaluateJavascript(
        source: 'document.cookie.includes("fixture-pass")',
      ),
      isFalse,
    );
    await controller.evaluateJavascript(
      source: 'history.replaceState(null, "", "#/fixture")',
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(InAppWebView), findsOneWidget);
    await controller.evaluateJavascript(
      source:
          'window.location.href = "https://api2.mina.mi.com/sts?hmusic_fixture=1";',
    );
    final captured = await pumpUntil(tester, result);
    expect(captured, isNotNull);
    expect(captured!.callbackUri?.host, 'api2.mina.mi.com');
    expect(captured.callbackUri?.path, '/sts');
    expect(captured.accountCookies['userId'], 'fixture-user');
    expect(captured.accountCookies['passToken'], 'fixture-pass');
    expect(
      await cookies.getCookies(url: WebUri('https://account.xiaomi.com/')),
      isEmpty,
    );
    expect(find.text('HMusic 验证返回测试'), findsOneWidget);
    expect(find.byType(InAppWebView), findsNothing);
    details.addAll({
      'httpOnlyCookieHandoff': true,
      'callbackIntercepted': true,
      'embeddedViewDisposed': true,
      'cookieCleanup': true,
      'returnedToFlutter': true,
      'ordinaryPageDoesNotFinishEarly': true,
    });

    final cancelled = harness.verifier.open(
      url: url,
      cookies: [
        for (var i = 0; i < 8; i++)
          io.Cookie('hmusicFixture$i', 'cancel')..path = '/',
      ],
    );
    await tester.pump();
    await tester.pump();
    await pumpUntil(tester, harness.pages.last.controller.future);
    final cancelling = harness.verifier.cancel();
    await pumpUntil(tester, cancelling);
    expect(await pumpUntil(tester, cancelled), isNull);
    expect(
      await cookies.getCookies(url: WebUri('https://account.xiaomi.com/')),
      isEmpty,
    );
    details['cancelWithNativeView'] = true;

    final unopened = harness.verifier.open(url: url, cookies: []);
    final cancelBeforeMount = harness.verifier.cancel();
    await pumpUntil(tester, cancelBeforeMount);
    expect(await pumpUntil(tester, unopened), isNull);
    expect(find.text('HMusic 验证返回测试'), findsOneWidget);
    details['cancelBeforePageMount'] = true;
    expect(tester.takeException(), isNull);
  });
}
