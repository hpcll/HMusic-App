import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/auth/mi_web_verifier.dart';
import 'package:hmusic/core/direct/mi_direct_providers.dart';
import 'package:hmusic/features/direct_auth/view_models/direct_verification_view_model.dart';

import 'support/verification_fakes.dart';

void main() {
  final login = Uri.parse('https://account.xiaomi.com/fe/service/login');
  final callback = Uri.parse('https://api2.mina.mi.com/sts?ticket=fixture');
  final authEnd = Uri.parse(
    'https://account.xiaomi.com/pass/serviceLoginAuth2/end',
  );
  late MiWebAuthRequest request;
  late FakeVerificationCookies cookies;
  late FakeVerificationDriver driver;
  late ProviderContainer container;
  late DirectVerificationViewModel vm;

  setUp(() {
    request = MiWebAuthRequest(url: login, cookies: []);
    cookies = FakeVerificationCookies();
    driver = FakeVerificationDriver();
    container = ProviderContainer(
      overrides: [miWebCookiesProvider.overrideWithValue(cookies)],
    );
    container.listen(directVerificationViewModelProvider(request), (_, _) {});
    vm = container.read(directVerificationViewModelProvider(request).notifier);
  });
  tearDown(() => container.dispose());

  test(
    'ordinary account pages never complete verification just because a token appeared',
    () async {
      cookies.accountValues = {'userId': '123', 'passToken': 'fixture'};
      await vm.attach(driver);
      await vm.loaded(login);
      await vm.visited(login.replace(fragment: '/verify'));
      final state = container.read(
        directVerificationViewModelProvider(request),
      );
      expect(state.closed, isFalse);
      expect(state.loading, isFalse);
      expect(cookies.accountReads, 0);
      expect(await vm.navigate(authEnd, mainFrame: true), isFalse);
      expect(
        container
            .read(directVerificationViewModelProvider(request))
            .result
            ?.accountCookies,
        cookies.accountValues,
      );
    },
  );

  test(
    'STS is intercepted once even if history and load events also arrive',
    () async {
      cookies.accountValues = {'userId': '123', 'passToken': 'fixture'};
      await vm.attach(driver);
      final allowed = vm.navigate(callback, mainFrame: true);
      await Future.wait([vm.visited(callback), vm.loaded(callback)]);
      expect(await allowed, isFalse);
      final state = container.read(
        directVerificationViewModelProvider(request),
      );
      expect(state.closed, isTrue);
      expect(state.result?.callbackUri, callback);
      expect(cookies.accountReads, 1);
      expect(driver.stops, 1);
    },
  );

  test(
    'pending auth-end cookie read does not drop the final callback',
    () async {
      cookies.reading = Completer<Map<String, String>>();
      await vm.attach(driver);
      final first = vm.navigate(authEnd, mainFrame: true);
      await Future<void>.delayed(Duration.zero);
      final finalNavigation = vm.navigate(callback, mainFrame: true);
      cookies.reading!.complete({});
      await first;
      expect(await finalNavigation, isFalse);
      expect(
        container
            .read(directVerificationViewModelProvider(request))
            .result
            ?.callbackUri,
        callback,
      );
    },
  );

  test(
    'load-stop cannot erase an error and leave a blank page; retry can recover',
    () async {
      await vm.attach(driver);
      vm.failed();
      await vm.loaded(login);
      expect(
        container
            .read(directVerificationViewModelProvider(request))
            .errorMessage,
        isNotNull,
      );
      await vm.retry();
      expect(driver.reloads, 1);
      await vm.loaded(login);
      expect(
        container
            .read(directVerificationViewModelProvider(request))
            .errorMessage,
        isNull,
      );
    },
  );

  test(
    'retry also recovers from failed cookie preparation before first load',
    () async {
      cookies.failPreparation = true;
      await vm.attach(driver);
      expect(driver.loads, isEmpty);
      cookies.failPreparation = false;
      await vm.retry();
      expect(cookies.preparations, 2);
      expect(driver.loads, [login]);
    },
  );

  test(
    'cancel during preparation prevents both loading and late completion',
    () async {
      cookies.preparing = Completer<void>();
      final preparation = vm.attach(driver);
      vm.cancel();
      cookies.preparing!.complete();
      await preparation;
      await vm.loaded(callback);
      expect(driver.loads, isEmpty);
      final state = container.read(
        directVerificationViewModelProvider(request),
      );
      expect(state.closed, isTrue);
      expect(state.result, isNull);
    },
  );

  test(
    'external top-level navigation is blocked while challenge subframes are allowed',
    () async {
      final external = Uri.parse('https://example.org/');
      expect(await vm.navigate(external, mainFrame: true), isFalse);
      expect(await vm.navigate(external, mainFrame: false), isTrue);
      expect(await vm.navigate(login, mainFrame: true), isTrue);
    },
  );
}
