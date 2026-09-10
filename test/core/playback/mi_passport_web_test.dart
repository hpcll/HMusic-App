import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/auth/mi_passport_client.dart';
import 'package:hmusic/core/direct/auth/mi_passport_http.dart';
import 'package:hmusic/core/direct/auth/mi_passport_result.dart';
import 'package:hmusic/core/direct/auth/mi_passport_web_exchange.dart';
import 'package:hmusic/core/direct/auth/mi_web_auth_policy.dart';
import 'package:hmusic/core/direct/auth/mi_web_verifier.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/storage/key_value_store.dart';

import 'support/fake_mi_web_verifier.dart';
import 'support/passport_adapter.dart';

void main() {
  final callback = Uri.parse(
    'https://api2.mina.mi.com/sts?ticket=fixture-secret',
  );
  final challenge = MiPassportChallenge(
    kind: MiChallengeKind.identity,
    url: Uri.parse('https://account.xiaomi.com/identity/authStart'),
  );

  test(
    'STS callback is consumed once and returns HttpOnly response cookies',
    () async {
      final adapter = PassportAdapter(
        (_) => passportResponse(
          '',
          status: 302,
          cookies: [
            'serviceToken=fixture-service; HttpOnly; Secure; Path=/',
            'userId=123; HttpOnly; Secure; Path=/',
          ],
        ),
      );
      final http = MiPassportHttp(adapter: adapter);
      addTearDown(http.close);
      final result = await MiPassportWebExchange(http).exchange(
        MiWebAuthResult(
          callbackUri: callback,
          accountCookies: {'userId': '123', 'passToken': 'fixture-pass'},
        ),
      );
      expect(result.userId, '123');
      expect(result.serviceToken, 'fixture-service');
      expect(result.passToken, 'fixture-pass');
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.options.followRedirects, isFalse);
      expect(
        adapter.requests.single.options.headers['User-Agent'],
        MiWebAuthPolicy.userAgent,
      );
      expect(result.toString(), isNot(contains('fixture')));
    },
  );

  test(
    'already loaded STS cookies are accepted without replaying its URL',
    () async {
      final adapter = PassportAdapter(
        (_) => throw StateError('unexpected request'),
      );
      final http = MiPassportHttp(adapter: adapter);
      addTearDown(http.close);
      final result = await MiPassportWebExchange(http).exchange(
        MiWebAuthResult(
          callbackUri: callback,
          serviceCookies: {'userId': '123', 'serviceToken': 'fixture-service'},
          accountCookies: {'userId': '456', 'passToken': 'other-account'},
        ),
      );
      expect(result.passToken, isNull);
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'STS JSON response is supported and HTML is never an authenticated session',
    () async {
      final adapter = PassportAdapter(
        (_) => passportResponse(
          '{"code":0,"userId":"123","serviceToken":"fixture-service"}',
        ),
      );
      final http = MiPassportHttp(adapter: adapter);
      addTearDown(http.close);
      final result = await MiPassportWebExchange(
        http,
      ).exchange(MiWebAuthResult(callbackUri: callback));
      expect(result.serviceToken, 'fixture-service');
      final html = MiPassportHttp(
        adapter: PassportAdapter(
          (_) => passportResponse('<html>fixture-secret</html>'),
        ),
      );
      addTearDown(html.close);
      await expectLater(
        MiPassportWebExchange(
          html,
        ).exchange(MiWebAuthResult(callbackUri: callback)),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'redacted',
            isNot(contains('fixture')),
          ),
        ),
      );
    },
  );

  for (final value in [
    'http://api2.mina.mi.com/sts',
    'https://api2.mina.mi.com.attacker.invalid/sts',
    'https://api2.mina.mi.com/other?next=/sts',
    'https://fixture@api2.mina.mi.com/sts',
    'https://api2.mina.mi.com:444/sts',
    'https://api2.mina.mi.com/sts#secret',
  ]) {
    test(
      'rejects untrusted callback even if cookies look valid: $value',
      () async {
        final adapter = PassportAdapter(
          (_) => throw StateError('unexpected request'),
        );
        final http = MiPassportHttp(adapter: adapter);
        addTearDown(http.close);
        final uri = Uri.parse(value);
        expect(MiWebAuthPolicy.isCallback(uri), isFalse);
        await expectLater(
          MiPassportWebExchange(http).exchange(
            MiWebAuthResult(
              callbackUri: uri,
              serviceCookies: {
                'userId': '123',
                'serviceToken': 'fixture-service',
              },
            ),
          ),
          throwsA(isA<ApiFailure>()),
        );
        expect(adapter.requests, isEmpty);
      },
    );
  }

  test(
    'web verification seeds both identity and /pass cookies, then exchanges its callback',
    () async {
      final adapter = PassportAdapter(
        (_) => passportResponse(
          '',
          cookies: [
            'serviceToken=fixture-service; Path=/',
            'userId=123; Path=/',
          ],
        ),
      );
      final http = MiPassportHttp(adapter: adapter);
      await http.cookies
          .saveFromResponse(MiPassportHttp.accountUri('/pass/getCode'), [
            Cookie('ick', 'fixture-ick')..path = '/pass',
            Cookie('deviceId', 'FIXTUREDEVICE123')..path = '/',
          ]);
      final verifier = FakeMiWebVerifier()
        ..result = MiWebAuthResult(callbackUri: callback);
      final client = MiPassportClient(
        http: http,
        preferences: MemoryKeyValueStore(),
        webVerifier: verifier,
      );
      addTearDown(client.close);
      expect(await client.verifyWeb(challenge), isA<MiPassportAuthenticated>());
      expect(
        verifier.seeded.map((c) => c.name),
        containsAll(['ick', 'deviceId']),
      );
      expect(adapter.requests, hasLength(1));
      expect(await http.cookies.loadForRequest(callback), isEmpty);
    },
  );

  test(
    'fresh browser passToken resumes the existing Passport exchange',
    () async {
      final adapter = PassportAdapter(
        (request) => request.options.uri.path == '/sts'
            ? passportResponse(
                '',
                cookies: ['serviceToken=fixture-service; Path=/'],
              )
            : passportResponse(
                '{"code":0,"userId":"123","ssecurity":"security","nonce":1,"location":"https://api2.mina.mi.com/sts"}',
              ),
      );
      final verifier = FakeMiWebVerifier()
        ..result = MiWebAuthResult(
          accountCookies: {'userId': '123', 'passToken': 'fixture-pass'},
        );
      final client = MiPassportClient(
        http: MiPassportHttp(adapter: adapter),
        preferences: MemoryKeyValueStore(),
        webVerifier: verifier,
      );
      addTearDown(client.close);
      final result =
          await client.verifyWeb(challenge) as MiPassportAuthenticated;
      expect(result.session.serviceToken, 'fixture-service');
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.first.cookie, contains('passToken=fixture-pass'));
      expect(
        adapter.requests.first.options.uri.queryParameters['sid'],
        'micoapi',
      );
    },
  );

  test(
    'closing verification releases a single-flight login without HTTP exchange',
    () async {
      final verifier = FakeMiWebVerifier()..pending = Completer();
      final adapter = PassportAdapter(
        (_) => throw StateError('unexpected request'),
      );
      final client = MiPassportClient(
        http: MiPassportHttp(adapter: adapter),
        preferences: MemoryKeyValueStore(),
        webVerifier: verifier,
      );
      addTearDown(client.close);
      final pending = client.verifyWeb(challenge);
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        client.verifyWeb(challenge),
        throwsA(isA<ApiFailure>()),
      );
      await client.cancelWebVerification();
      expect(await pending, isNull);
      expect(verifier.opens, 1);
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'account SPA fragments are allowed without accepting other origins or schemes',
    () {
      expect(
        MiWebAuthPolicy.isAccount(
          Uri.parse('https://account.xiaomi.com/fe/service/login#/verify'),
        ),
        isTrue,
      );
      for (final url in [
        'https://account.xiaomi.com.attacker.invalid/',
        'javascript:alert(1)',
        'http://account.xiaomi.com/',
        'https://account.xiaomi.com@attacker.invalid/',
      ]) {
        expect(MiWebAuthPolicy.isAccount(Uri.parse(url)), isFalse);
      }
    },
  );
}
