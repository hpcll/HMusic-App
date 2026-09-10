import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/auth/mi_direct_login_result.dart';
import 'package:hmusic/core/direct/auth/mi_passport_client.dart';
import 'package:hmusic/core/direct/auth/mi_passport_result.dart';
import 'package:hmusic/core/direct/mi_direct_account_repository.dart';
import 'package:hmusic/core/direct/mi_direct_session.dart';
import 'package:hmusic/core/direct/mi_direct_session_store.dart';
import 'package:hmusic/core/direct/mi_mina_client.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:mocktail/mocktail.dart';

class _Passport extends Mock implements MiPassportClient {}

class _Client extends Mock implements MiMinaClient {}

class _Store extends Mock implements MiDirectSessionStore {}

void main() {
  late _Passport passport;
  late _Client client;
  late _Store store;
  late MiDirectAccountRepository repository;
  final session = MiDirectSession(userId: '123', serviceToken: 'fixture');

  setUp(() {
    passport = _Passport();
    client = _Client();
    store = _Store();
    repository = MiDirectAccountRepository(
      client: client,
      store: store,
      passport: passport,
    );
    when(() => client.devices(session)).thenAnswer((_) async => []);
    when(() => store.write(session)).thenAnswer((_) async {});
    when(() => store.clear()).thenAnswer((_) async {});
    when(() => passport.reset()).thenAnswer((_) async {});
    when(() => passport.cancelWebVerification()).thenAnswer((_) async {});
  });

  test(
    'password success validates devices before committing the secure session',
    () async {
      when(
        () => passport.login(
          account: 'account',
          password: 'password',
          captchaCode: null,
        ),
      ).thenAnswer((_) async => MiPassportAuthenticated(session));
      final result = await repository.loginPassword(
        account: 'account',
        password: 'password',
      );
      expect(result, isA<MiDirectLoginAuthenticated>());
      verifyInOrder([
        () => client.devices(session),
        () => store.write(session),
      ]);
    },
  );

  test('challenge does not save unverified credentials', () async {
    final challenge = MiPassportChallenge(
      kind: MiChallengeKind.identity,
      url: Uri.parse('https://account.xiaomi.com/identity/authStart'),
    );
    when(
      () => passport.login(
        account: 'account',
        password: 'password',
        captchaCode: null,
      ),
    ).thenAnswer((_) async => challenge);
    expect(
      await repository.loginPassword(account: 'account', password: 'password'),
      isA<MiDirectLoginChallenge>(),
    );
    verifyZeroInteractions(store);
    verifyZeroInteractions(client);
  });

  test(
    'logout invalidates an in-flight login before it can save credentials',
    () async {
      final gate = Completer<MiPassportResult>();
      when(
        () => passport.login(
          account: 'account',
          password: 'password',
          captchaCode: null,
        ),
      ).thenAnswer((_) => gate.future);
      final login = expectLater(
        repository.loginPassword(account: 'account', password: 'password'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.code,
            'code',
            'MI_DIRECT_LOGIN_CANCELLED',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final logout = repository.logout();
      gate.complete(MiPassportAuthenticated(session));
      await login;
      await logout;
      verifyNever(() => store.write(session));
      verify(() => store.clear()).called(1);
    },
  );

  test(
    'web completion validates devices before persisting and cancellation discards late results',
    () async {
      final challenge = MiPassportChallenge(
        kind: MiChallengeKind.identity,
        url: Uri.parse('https://account.xiaomi.com/identity/authStart'),
      );
      when(
        () => passport.verifyWeb(challenge),
      ).thenAnswer((_) async => MiPassportAuthenticated(session));
      expect(
        await repository.verifyWeb(challenge),
        isA<MiDirectLoginAuthenticated>(),
      );
      verifyInOrder([
        () => client.devices(session),
        () => store.write(session),
      ]);
      clearInteractions(store);
      final gate = Completer<MiPassportResult?>();
      when(() => passport.verifyWeb(challenge)).thenAnswer((_) => gate.future);
      final pending = expectLater(
        repository.verifyWeb(challenge),
        throwsA(isA<ApiFailure>()),
      );
      await Future<void>.delayed(Duration.zero);
      final cancelled = repository.cancelLogin();
      verify(() => passport.cancelWebVerification()).called(1);
      gate.complete(MiPassportAuthenticated(session));
      await pending;
      await cancelled;
      verifyNever(() => store.write(session));
    },
  );
}
