import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/auth/mi_passport_client.dart';
import 'package:hmusic/core/direct/auth/mi_passport_http.dart';
import 'package:hmusic/core/direct/auth/mi_passport_result.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/storage/key_value_store.dart';

import 'support/passport_adapter.dart';

const _sign =
    '&&&START&&&{"_sign":"fixture-sign","qs":"query","callback":"https://api2.mina.mi.com/sts"}';
const _success =
    '''&&&START&&&{"code":0,"userId":123,"ssecurity":"fixture-security",
"nonce":9223372036854775806,"passToken":"fixture-pass",
"location":"https://api2.mina.mi.com/sts?ticket=a%2Bb"}''';

void main() {
  late MemoryKeyValueStore preferences;
  late List<int> captchaBytes;
  setUpAll(() async {
    captchaBytes = await File('assets/icon/brand-mark.png').readAsBytes();
  });
  setUp(() => preferences = MemoryKeyValueStore());

  MiPassportClient create(PassportAdapter adapter) {
    final client = MiPassportClient(
      http: MiPassportHttp(adapter: adapter),
      preferences: preferences,
    );
    addTearDown(client.close);
    return client;
  }

  test(
    'password login preserves 64-bit nonce and accepts STS 302 token without redirect',
    () async {
      final adapter = PassportAdapter((request) {
        switch (request.options.uri.path) {
          case '/pass/serviceLogin':
            return passportResponse(_sign);
          case '/pass/serviceLoginAuth2':
            return passportResponse(_success);
          case '/sts':
            return passportResponse(
              '',
              status: 302,
              cookies: ['serviceToken=fixture-token; Path=/; Secure; HttpOnly'],
            );
          default:
            throw StateError('unexpected request');
        }
      });
      final result = await create(
        adapter,
      ).login(account: ' account ', password: 'password');
      expect(result, isA<MiPassportAuthenticated>());
      final session = (result as MiPassportAuthenticated).session;
      expect(session.userId, '123');
      expect(session.serviceToken, 'fixture-token');
      final form = adapter.requests[1].form;
      expect(form['hash'], '5F4DCC3B5AA765D61D8327DEB882CF99');
      expect(form['user'], 'account');
      expect(form['sid'], 'micoapi');
      final expectedSign = base64Encode(
        sha1
            .convert(utf8.encode('nonce=9223372036854775806&fixture-security'))
            .bytes,
      );
      final sts = adapter.requests[2];
      expect(sts.options.uri.queryParameters['clientSign'], expectedSign);
      expect(sts.options.uri.queryParameters['ticket'], 'a+b');
      expect(sts.options.followRedirects, isFalse);
      expect(sts.cookie, isEmpty);
      expect(
        adapter.requests.every(
          (r) => !r.options.headers.containsKey('Authorization'),
        ),
        isTrue,
      );
    },
  );

  test(
    'captcha image and second password submission share sign and issued Cookie',
    () async {
      var authCalls = 0;
      final adapter = PassportAdapter((request) {
        switch (request.options.uri.path) {
          case '/pass/serviceLogin':
            return passportResponse(_sign);
          case '/pass/serviceLoginAuth2':
            authCalls++;
            return authCalls == 1
                ? passportResponse(
                    '{"code":87001,"captchaUrl":"/pass/getCode?ticket=fixture"}',
                    cookies: [
                      'ick=captcha-session; Path=/pass; Secure; HttpOnly',
                    ],
                  )
                : passportResponse(_success);
          case '/pass/getCode':
            return passportImageResponse(captchaBytes);
          case '/sts':
            return passportResponse(
              '',
              status: 302,
              cookies: ['serviceToken=fixture-token; Path=/'],
            );
          default:
            throw StateError('unexpected request');
        }
      });
      final client = create(adapter);
      final challenge =
          await client.login(account: 'account', password: 'password')
              as MiPassportChallenge;
      expect(challenge.kind, MiChallengeKind.captcha);
      expect(await client.captchaImage(challenge), captchaBytes);
      expect(
        await client.login(
          account: 'account',
          password: 'password',
          captchaCode: 'abcd',
        ),
        isA<MiPassportAuthenticated>(),
      );
      expect(
        adapter.requests.where(
          (r) => r.options.uri.path == '/pass/serviceLogin',
        ),
        hasLength(1),
      );
      final submissions = adapter.requests
          .where((r) => r.options.uri.path == '/pass/serviceLoginAuth2')
          .toList();
      expect(submissions.last.cookie, contains('ick=captcha-session'));
      expect(submissions.last.cookie, contains('deviceId='));
      expect(submissions.last.form['captCode'], 'abcd');
      expect(adapter.requests.last.cookie, isEmpty);
    },
  );

  test(
    'identity challenge is a distinct result even with successful code',
    () async {
      final adapter = PassportAdapter(
        (r) => passportResponse(
          r.options.method == 'GET'
              ? _sign
              : '{"code":0,"notificationUrl":"https://account.xiaomi.com/identity/authStart?ticket=fixture"}',
        ),
      );
      final result =
          await create(adapter).login(account: 'account', password: 'password')
              as MiPassportChallenge;
      expect(result.kind, MiChallengeKind.identity);
      expect(result.toString(), isNot(contains('ticket')));
      expect(adapter.requests, hasLength(2));
    },
  );

  test(
    'passToken exchange sends passport Cookie only to account host',
    () async {
      final adapter = PassportAdapter(
        (r) => r.options.uri.path == '/sts'
            ? passportResponse(
                '',
                cookies: ['serviceToken=fixture-token; Path=/'],
              )
            : passportResponse(_success),
      );
      final result = await create(
        adapter,
      ).loginWithPassToken(userId: '123', passToken: 'fixture-pass');
      expect(result, isA<MiPassportAuthenticated>());
      expect(adapter.requests.first.cookie, contains('passToken=fixture-pass'));
      expect(adapter.requests.last.cookie, isEmpty);
    },
  );

  test(
    'upstream descriptions and credentials are not exposed on failure',
    () async {
      final adapter = PassportAdapter(
        (r) => passportResponse(
          r.options.method == 'GET'
              ? _sign
              : '{"code":70016,"desc":"secret-fixture-response"}',
        ),
      );
      await expectLater(
        create(adapter).login(account: 'account', password: 'password'),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.code, 'code', 'MI_DIRECT_LOGIN_REJECTED')
              .having(
                (e) => e.toString(),
                'redacted',
                isNot(contains('secret')),
              ),
        ),
      );
      expect(adapter.requests, hasLength(2));
    },
  );

  test(
    'login is single-flight so concurrent requests cannot mix captcha state',
    () async {
      final gate = Completer<void>();
      final adapter = PassportAdapter((_) async {
        await gate.future;
        return passportResponse('{"code":500}');
      });
      final client = create(adapter);
      final first = expectLater(
        client.login(account: 'first', password: 'password'),
        throwsA(isA<ApiFailure>()),
      );
      await expectLater(
        client.login(account: 'second', password: 'password'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.code,
            'code',
            'MI_DIRECT_LOGIN_BUSY',
          ),
        ),
      );
      gate.complete();
      await first;
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    'untrusted STS destination is rejected before sending credentials',
    () async {
      final adapter = PassportAdapter(
        (r) => passportResponse(
          r.options.method == 'GET'
              ? _sign
              : _success.replaceFirst('api2.mina.mi.com', 'attacker.invalid'),
        ),
      );
      await expectLater(
        create(adapter).login(account: 'account', password: 'password'),
        throwsA(isA<ApiFailure>()),
      );
      expect(adapter.requests, hasLength(2));
    },
  );
}
