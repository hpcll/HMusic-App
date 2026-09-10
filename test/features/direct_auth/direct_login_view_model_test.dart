import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/auth/mi_direct_login_result.dart';
import 'package:hmusic/core/direct/auth/mi_passport_result.dart';
import 'package:hmusic/core/direct/mi_direct_account_repository.dart';
import 'package:hmusic/core/direct/mi_direct_providers.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/features/direct_auth/view_models/direct_login_view_model.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements MiDirectAccountRepository {}

void main() {
  late _Repository repository;
  late ProviderContainer container;
  final account = MiDirectAccount(userId: '123', devices: []);

  setUp(() {
    repository = _Repository();
    when(() => repository.cancelLogin()).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        miDirectAccountRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  void reply(Future<MiDirectLoginResult> Function() action) {
    when(
      () => repository.loginPassword(
        account: 'account',
        password: 'password',
        captchaCode: null,
      ),
    ).thenAnswer((_) => action());
  }

  test(
    'successful login publishes account without Server session side effects',
    () async {
      reply(() async => MiDirectLoginAuthenticated(account));
      await container
          .read(directLoginViewModelProvider.notifier)
          .login(account: 'account', password: 'password');
      final state = container.read(directLoginViewModelProvider);
      expect(state.account, same(account));
      expect(state.busy, isFalse);
      expect(state.challenge, isNull);
      expect(state.errorMessage, isNull);
    },
  );

  test('captcha image failure leaves challenge available for retry', () async {
    final challenge = MiPassportChallenge(
      kind: MiChallengeKind.captcha,
      url: Uri.parse('https://account.xiaomi.com/pass/getCode'),
    );
    reply(() async => MiDirectLoginChallenge(challenge));
    when(() => repository.captchaImage(challenge)).thenThrow(
      const ApiFailure(kind: ApiFailureKind.offline, message: '验证码加载失败'),
    );
    final vm = container.read(directLoginViewModelProvider.notifier);
    await vm.login(account: 'account', password: 'password');
    var state = container.read(directLoginViewModelProvider);
    expect(state.challenge, same(challenge));
    expect(state.busy, isFalse);
    expect(state.errorMessage, '验证码加载失败');
    when(
      () => repository.captchaImage(challenge),
    ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
    await vm.refreshCaptcha();
    state = container.read(directLoginViewModelProvider);
    expect(state.captchaImage, [1, 2, 3]);
    expect(state.errorMessage, isNull);
  });

  test(
    'secure storage errors release busy state and redact plugin error details',
    () async {
      reply(
        () async =>
            throw PlatformException(code: 'locked', message: 'fixture-secret'),
      );
      await container
          .read(directLoginViewModelProvider.notifier)
          .login(account: 'account', password: 'password');
      final state = container.read(directLoginViewModelProvider);
      expect(state.busy, isFalse);
      expect(state.errorMessage, isNot(contains('fixture-secret')));
      expect(state.errorMessage, isNotNull);
    },
  );

  test(
    'failed refresh clears the previous image after its cookie may change',
    () async {
      final challenge = MiPassportChallenge(
        kind: MiChallengeKind.captcha,
        url: Uri.parse('https://account.xiaomi.com/pass/getCode'),
      );
      reply(() async => MiDirectLoginChallenge(challenge));
      when(
        () => repository.captchaImage(challenge),
      ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
      final vm = container.read(directLoginViewModelProvider.notifier);
      await vm.login(account: 'account', password: 'password');
      final refresh = Completer<Uint8List>();
      when(
        () => repository.captchaImage(challenge),
      ).thenAnswer((_) => refresh.future);
      final pending = vm.refreshCaptcha();
      expect(container.read(directLoginViewModelProvider).captchaImage, isNull);
      expect(container.read(directLoginViewModelProvider).busy, isTrue);
      refresh.completeError(
        const ApiFailure(kind: ApiFailureKind.offline, message: '验证码加载失败'),
      );
      await pending;
      final state = container.read(directLoginViewModelProvider);
      expect(state.captchaImage, isNull);
      expect(state.challenge, same(challenge));
      expect(state.busy, isFalse);
      expect(state.errorMessage, '验证码加载失败');
    },
  );

  test(
    'cancel discards late authentication and duplicate submit stays single-flight',
    () async {
      final gate = Completer<MiDirectLoginResult>();
      reply(() => gate.future);
      final vm = container.read(directLoginViewModelProvider.notifier);
      final pending = vm.login(account: 'account', password: 'password');
      await vm.login(account: 'account', password: 'password');
      await vm.cancel();
      gate.complete(MiDirectLoginAuthenticated(account));
      await pending;
      expect(container.read(directLoginViewModelProvider).account, isNull);
      expect(container.read(directLoginViewModelProvider).busy, isFalse);
      verify(
        () => repository.loginPassword(
          account: 'account',
          password: 'password',
          captchaCode: null,
        ),
      ).called(1);
      verify(() => repository.cancelLogin()).called(1);
    },
  );

  test(
    'App verification completion publishes the account and ignores duplicate taps',
    () async {
      final challenge = MiPassportChallenge(
        kind: MiChallengeKind.identity,
        url: Uri.parse('https://account.xiaomi.com/identity/authStart'),
      );
      reply(() async => MiDirectLoginChallenge(challenge));
      final gate = Completer<MiDirectLoginResult?>();
      when(
        () => repository.verifyWeb(challenge),
      ).thenAnswer((_) => gate.future);
      final vm = container.read(directLoginViewModelProvider.notifier);
      await vm.login(account: 'account', password: 'password');
      final pending = vm.openVerification();
      await vm.openVerification();
      expect(container.read(directLoginViewModelProvider).busy, isTrue);
      gate.complete(MiDirectLoginAuthenticated(account));
      await pending;
      expect(
        container.read(directLoginViewModelProvider).account,
        same(account),
      );
      expect(container.read(directLoginViewModelProvider).challenge, isNull);
      verify(() => repository.verifyWeb(challenge)).called(1);
    },
  );

  test(
    'closing App verification keeps login retryable without claiming success',
    () async {
      final challenge = MiPassportChallenge(
        kind: MiChallengeKind.identity,
        url: Uri.parse('https://account.xiaomi.com/identity/authStart'),
      );
      reply(() async => MiDirectLoginChallenge(challenge));
      when(() => repository.verifyWeb(challenge)).thenAnswer((_) async => null);
      final vm = container.read(directLoginViewModelProvider.notifier);
      await vm.login(account: 'account', password: 'password');
      await vm.openVerification();
      final state = container.read(directLoginViewModelProvider);
      expect(state.busy, isFalse);
      expect(state.account, isNull);
      expect(state.challenge, same(challenge));
      expect(state.errorMessage, isNull);
    },
  );

  test(
    'cancel while App verification is open ignores its late authenticated result',
    () async {
      final challenge = MiPassportChallenge(
        kind: MiChallengeKind.identity,
        url: Uri.parse('https://account.xiaomi.com/identity/authStart'),
      );
      reply(() async => MiDirectLoginChallenge(challenge));
      final gate = Completer<MiDirectLoginResult?>();
      when(
        () => repository.verifyWeb(challenge),
      ).thenAnswer((_) => gate.future);
      final vm = container.read(directLoginViewModelProvider.notifier);
      await vm.login(account: 'account', password: 'password');
      final pending = vm.openVerification();
      await vm.cancel();
      gate.complete(MiDirectLoginAuthenticated(account));
      await pending;
      expect(container.read(directLoginViewModelProvider).account, isNull);
      expect(container.read(directLoginViewModelProvider).busy, isFalse);
    },
  );

  test(
    'dispose cancels outstanding login and ignores its late result',
    () async {
      final gate = Completer<MiDirectLoginResult>();
      reply(() => gate.future);
      final pending = container
          .read(directLoginViewModelProvider.notifier)
          .login(account: 'account', password: 'password');
      container.invalidate(directLoginViewModelProvider);
      gate.complete(MiDirectLoginAuthenticated(account));
      await pending;
      verify(() => repository.cancelLogin()).called(1);
    },
  );
}
