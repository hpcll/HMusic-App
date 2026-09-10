import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/auth/mi_web_login_prefill.dart';
import 'package:hmusic/features/direct_auth/data/direct_verification_driver.dart';

import 'verification_harness.dart';

const prefillFixtureAccount = 'hmusic-check@example.invalid';
const prefillFixturePassword = 'Fixture-"quote"-\\-雪-123!';

Future<void> verifyPublicPrefill(InAppWebViewController controller) async {
  final result = await controller.callAsyncJavaScript(
    functionBody: r'''
const secret = document.querySelector('input[type="password"]');
const fields = [...document.querySelectorAll('input')];
return !!secret && secret.value === password && fields.some(field => field.value === account);
''',
    arguments: {
      'account': prefillFixtureAccount,
      'password': prefillFixturePassword,
    },
  );
  if (result?.value != true) {
    final diagnostic = await controller.callAsyncJavaScript(
      functionBody: r'''
return {path: location.pathname, origin: location.origin, fields: [...document.querySelectorAll('input')].map(field => ({
  type: field.type, name: field.name, placeholder: field.placeholder,
  length: field.value.length, visible: field.getClientRects().length > 0,
  matchesAccount: field.value === account, matchesPassword: field.value === password,
}))};
''',
      arguments: {
        'account': prefillFixtureAccount,
        'password': prefillFixturePassword,
      },
    );
    fail('小米原站预填未通过；表单结构：${diagnostic?.value}；执行错误：${result?.error}');
  }
}

Future<void> verifyPrefillFixtures(
  WidgetTester tester,
  ObservedVerification page,
  InAppWebViewController controller,
) async {
  Future<void> load(String html) async {
    final loaded = page.loadedPages.stream.first;
    await controller.loadData(
      data:
          '<!doctype html><meta name="viewport" content="width=device-width">$html',
      baseUrl: WebUri('https://account.xiaomi.com/fe/service/login'),
    );
    await pumpUntil(tester, loaded);
  }

  MiWebLoginPrefill values() => MiWebLoginPrefill(
    account: prefillFixtureAccount,
    password: prefillFixturePassword,
  );
  final driver = InAppVerificationDriver(controller);
  await load(r'''
<script>
window.submits = 0; window.changes = 0;
setTimeout(() => {
  document.body.innerHTML = '<form><input name="account"><input type="password"><input name="captcha"><input type="checkbox"><button>登录</button></form>';
  document.querySelector('form').onsubmit = event => { event.preventDefault(); window.submits++; };
  document.addEventListener('input', () => window.changes++);
}, 500);
</script>
''');
  expect(await pumpUntil(tester, driver.fillLogin(values())), isTrue);
  await verifyPublicPrefill(controller);
  expect(await controller.evaluateJavascript(source: 'window.changes'), 2);
  expect(await controller.evaluateJavascript(source: 'window.submits'), 0);
  expect(
    await controller.evaluateJavascript(
      source: 'document.querySelector("input[name=captcha]").value',
    ),
    '',
  );
  expect(
    await controller.evaluateJavascript(
      source: 'document.querySelector("input[type=checkbox]").checked',
    ),
    isFalse,
  );

  await load(
    '<form><input name="account" value="user-edited"><input type="password" value="manual-value"></form>',
  );
  expect(await driver.fillLogin(values()), isTrue);
  expect(
    await controller.evaluateJavascript(
      source: 'document.querySelector("input[name=account]").value',
    ),
    'user-edited',
  );
  expect(
    await controller.evaluateJavascript(
      source: 'document.querySelector("input[type=password]").value',
    ),
    'manual-value',
  );

  // 正式验证页禁止外域导航，用独立 WebView 验证脚本本身的来源限制。
  final foreignLoaded = Completer<InAppWebViewController>();
  final foreignPage = HeadlessInAppWebView(
    initialData: InAppWebViewInitialData(
      data: '<form><input name="account"><input type="password"></form>',
      baseUrl: WebUri('https://example.org/fe/service/login'),
    ),
    onLoadStop: (controller, url) {
      if (url?.host == 'example.org' && !foreignLoaded.isCompleted) {
        foreignLoaded.complete(controller);
      }
    },
  );
  try {
    await foreignPage.run();
    final foreignController = await pumpUntil(tester, foreignLoaded.future);
    expect(
      await foreignController.evaluateJavascript(source: 'location.origin'),
      'https://example.org',
    );
    expect(
      await InAppVerificationDriver(foreignController).fillLogin(values()),
      isFalse,
    );
    expect(
      await foreignController.evaluateJavascript(
        source:
            '[...document.querySelectorAll("input")].every(input => input.value === "")',
      ),
      isTrue,
    );
  } finally {
    await foreignPage.dispose();
  }
}
