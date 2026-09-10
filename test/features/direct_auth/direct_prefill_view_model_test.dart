import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/auth/mi_direct_login_result.dart';
import 'package:hmusic/core/direct/auth/mi_passport_result.dart';
import 'package:hmusic/core/direct/auth/mi_web_login_prefill.dart';
import 'package:hmusic/core/direct/auth/mi_web_verifier.dart';
import 'package:hmusic/core/direct/mi_direct_account_repository.dart';
import 'package:hmusic/core/direct/mi_direct_providers.dart';
import 'package:hmusic/features/direct_auth/view_models/direct_login_view_model.dart';
import 'package:hmusic/features/direct_auth/view_models/direct_verification_view_model.dart';
import 'package:mocktail/mocktail.dart';

import 'support/verification_fakes.dart';

class _Repository extends Mock implements MiDirectAccountRepository {}

void main() {
  final login = Uri.parse('https://account.xiaomi.com/fe/service/login');

  test(
    'account is trimmed, password is literal and cancellation releases both',
    () {
      final prefill = MiWebLoginPrefill(
        account: ' user@example.invalid ',
        password: ' "quote" \\ newline\n雪 ',
      );
      final request = MiWebAuthRequest(
        url: login,
        cookies: [],
        prefill: prefill,
      );
      expect(prefill.account, 'user@example.invalid');
      expect(prefill.password, ' "quote" \\ newline\n雪 ');
      expect(prefill.toString(), isNot(contains('quote')));
      request.cancel();
      expect(prefill.isEmpty, isTrue);
      expect(prefill.password, isEmpty);
      expect(request.toString(), isNot(contains('example')));
    },
  );

  test(
    'verification fills once, waits for dynamic content and releases the values',
    () async {
      final prefill = MiWebLoginPrefill(account: 'user', password: 'fixture');
      final request = MiWebAuthRequest(
        url: login,
        cookies: [],
        prefill: prefill,
      );
      final cookies = FakeVerificationCookies();
      final driver = FakeVerificationDriver()..filling = Completer<bool>();
      final container = ProviderContainer(
        overrides: [miWebCookiesProvider.overrideWithValue(cookies)],
      );
      addTearDown(container.dispose);
      container.listen(directVerificationViewModelProvider(request), (_, _) {});
      final vm = container.read(
        directVerificationViewModelProvider(request).notifier,
      );
      await vm.attach(driver);
      final loading = vm.loaded(login);
      await Future<void>.delayed(Duration.zero);
      await vm.loaded(login);
      expect(driver.filledAccounts, ['user']);
      driver.filling!.complete(true);
      await loading;
      await vm.loaded(login);
      expect(driver.filledAccounts, ['user']);
      expect(prefill.isEmpty, isTrue);
    },
  );

  test(
    'external navigation and cancelling before page creation never fill',
    () async {
      final prefill = MiWebLoginPrefill(account: 'user', password: 'fixture');
      final request = MiWebAuthRequest(
        url: login,
        cookies: [],
        prefill: prefill,
      );
      final cookies = FakeVerificationCookies();
      final driver = FakeVerificationDriver();
      final container = ProviderContainer(
        overrides: [miWebCookiesProvider.overrideWithValue(cookies)],
      );
      addTearDown(container.dispose);
      container.listen(directVerificationViewModelProvider(request), (_, _) {});
      final vm = container.read(
        directVerificationViewModelProvider(request).notifier,
      );
      await vm.loaded(Uri.parse('https://example.org/'));
      vm.cancel();
      await vm.attach(driver);
      await vm.loaded(login);
      expect(driver.filledAccounts, isEmpty);
      expect(prefill.isEmpty, isTrue);
    },
  );

  test(
    'login passes current form values through authentication and clears them on return',
    () async {
      final repository = _Repository();
      final challenge = MiPassportChallenge(
        kind: MiChallengeKind.identity,
        url: login,
      );
      when(() => repository.cancelLogin()).thenAnswer((_) async {});
      when(
        () => repository.loginPassword(
          account: 'user',
          password: 'original',
          captchaCode: null,
        ),
      ).thenAnswer((_) async => MiDirectLoginChallenge(challenge));
      registerFallbackValue(MiWebLoginPrefill(account: '', password: ''));
      final gate = Completer<MiDirectLoginResult?>();
      MiWebLoginPrefill? captured;
      when(
        () => repository.verifyWeb(challenge, prefill: any(named: 'prefill')),
      ).thenAnswer((call) {
        captured = call.namedArguments[#prefill] as MiWebLoginPrefill;
        return gate.future;
      });
      final container = ProviderContainer(
        overrides: [
          miDirectAccountRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final vm = container.read(directLoginViewModelProvider.notifier);
      await vm.login(account: 'user', password: 'original');
      final pending = vm.openVerification(
        account: 'edited',
        password: 'new fixture password',
      );
      expect(captured?.account, 'edited');
      expect(captured?.password, 'new fixture password');
      gate.complete(null);
      await pending;
      expect(captured?.isEmpty, isTrue);
      expect(
        container.read(directLoginViewModelProvider).challenge,
        same(challenge),
      );
    },
  );
}
