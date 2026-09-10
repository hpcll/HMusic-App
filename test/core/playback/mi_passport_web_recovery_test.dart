import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/auth/mi_passport_client.dart';
import 'package:hmusic/core/direct/auth/mi_passport_http.dart';
import 'package:hmusic/core/direct/auth/mi_passport_result.dart';
import 'package:hmusic/core/direct/auth/mi_web_auth_policy.dart';
import 'package:hmusic/core/direct/auth/mi_web_verifier.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/storage/key_value_store.dart';

import 'support/fake_mi_web_verifier.dart';
import 'support/passport_adapter.dart';

void main() {
  final callback = Uri.parse('https://api2.mina.mi.com/sts?ticket=expired');
  final challenge = MiPassportChallenge(
    kind: MiChallengeKind.identity,
    url: Uri.parse('https://account.xiaomi.com/identity/authStart'),
  );
  const account = {'userId': '123', 'passToken': 'fixture-pass'};
  const success =
      '{"code":0,"userId":"123","ssecurity":"security","nonce":1,"location":"https://api2.mina.mi.com/sts?ticket=fresh"}';

  MiPassportClient clientFor(PassportAdapter adapter, MiWebAuthResult result) {
    final client = MiPassportClient(
      http: MiPassportHttp(adapter: adapter),
      preferences: MemoryKeyValueStore(),
      webVerifier: FakeMiWebVerifier()..result = result,
    );
    addTearDown(client.close);
    return client;
  }

  test(
    'existing service session wins over passToken and never replays STS',
    () async {
      final adapter = PassportAdapter(
        (_) => throw StateError('unexpected HTTP'),
      );
      final client = clientFor(
        adapter,
        MiWebAuthResult(
          callbackUri: callback,
          accountCookies: account,
          serviceCookies: {'serviceToken': 'fixture-service'},
        ),
      );
      final result =
          await client.verifyWeb(challenge) as MiPassportAuthenticated;
      expect(result.session.userId, '123');
      expect(result.session.serviceToken, 'fixture-service');
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'fresh passToken succeeds even when the browser callback would return 400',
    () async {
      final adapter = PassportAdapter((r) {
        if (r.options.uri.queryParameters['ticket'] == 'expired') {
          return passportResponse('expired', status: 400);
        }
        return r.options.uri.path == '/sts'
            ? passportResponse(
                '',
                status: 302,
                cookies: ['serviceToken=fixture-service; Path=/'],
              )
            : passportResponse(success);
      });
      final client = clientFor(
        adapter,
        MiWebAuthResult(callbackUri: callback, accountCookies: account),
      );
      expect(await client.verifyWeb(challenge), isA<MiPassportAuthenticated>());
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.first.cookie, contains('passToken=fixture-pass'));
      expect(
        adapter.requests.first.options.headers['User-Agent'],
        contains('iosPassportSDK'),
      );
      expect(
        adapter.requests.last.options.uri.queryParameters['ticket'],
        'fresh',
      );
    },
  );

  test(
    'rejected passToken falls back once to the untouched browser callback',
    () async {
      final adapter = PassportAdapter(
        (r) => r.options.uri.path == '/sts'
            ? passportResponse(
                '',
                cookies: ['serviceToken=fixture-service; Path=/'],
              )
            : passportResponse('fixture-secret', status: 403),
      );
      final client = clientFor(
        adapter,
        MiWebAuthResult(callbackUri: callback, accountCookies: account),
      );
      final result =
          await client.verifyWeb(challenge) as MiPassportAuthenticated;
      expect(result.session.userId, '123');
      expect(adapter.requests, hasLength(2));
      expect(
        adapter.requests.last.options.headers['User-Agent'],
        MiWebAuthPolicy.userAgent,
      );
    },
  );

  test(
    'both rejected exchanges stop after one fallback with a redacted HTTP error',
    () async {
      final adapter = PassportAdapter(
        (_) => passportResponse('fixture-secret', status: 400),
      );
      final client = clientFor(
        adapter,
        MiWebAuthResult(callbackUri: callback, accountCookies: account),
      );
      await expectLater(
        client.verifyWeb(challenge),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.statusCode, 'HTTP status', 400)
              .having((e) => e.code, 'stage', 'MI_DIRECT_STS_REJECTED')
              .having((e) => e.message, 'message', isNot(contains('检查网络')))
              .having(
                (e) => e.toString(),
                'redacted',
                isNot(contains('fixture')),
              ),
        ),
      );
      expect(adapter.requests, hasLength(2));
    },
  );

  test(
    'callback origin is checked before accepting even complete cookies',
    () async {
      final adapter = PassportAdapter(
        (_) => throw StateError('unexpected HTTP'),
      );
      final client = clientFor(
        adapter,
        MiWebAuthResult(
          callbackUri: Uri.parse('https://attacker.invalid/sts'),
          accountCookies: account,
          serviceCookies: {'userId': '123', 'serviceToken': 'fixture-service'},
        ),
      );
      await expectLater(
        client.verifyWeb(challenge),
        throwsA(isA<ApiFailure>()),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'cancelling a pending exchange suppresses fallback and its result',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final adapter = PassportAdapter((_) async {
        entered.complete();
        await release.future;
        return passportResponse('', status: 403);
      });
      final client = clientFor(
        adapter,
        MiWebAuthResult(callbackUri: callback, accountCookies: account),
      );
      final pending = client.verifyWeb(challenge);
      await entered.future;
      await client.cancelWebVerification();
      release.complete();
      expect(await pending, isNull);
      expect(adapter.requests, hasLength(1));
    },
  );
}
