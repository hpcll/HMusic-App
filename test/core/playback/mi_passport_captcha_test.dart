import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/auth/mi_passport_client.dart';
import 'package:hmusic/core/direct/auth/mi_passport_http.dart';
import 'package:hmusic/core/direct/auth/mi_passport_result.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/storage/key_value_store.dart';

import 'support/passport_adapter.dart';

void main() {
  late List<int> imageBytes;
  setUpAll(() async {
    imageBytes = await File('assets/icon/brand-mark.png').readAsBytes();
  });

  MiPassportClient client(PassportAdapter adapter) {
    final client = MiPassportClient(
      http: MiPassportHttp(adapter: adapter),
      preferences: MemoryKeyValueStore(),
    );
    addTearDown(client.close);
    return client;
  }

  final challenge = MiPassportChallenge(
    kind: MiChallengeKind.captcha,
    url: Uri.parse(
      'https://account.xiaomi.com/pass/getCode?icodeType=antispam',
    ),
  );

  test(
    'sign login-page fallback is a web challenge, never a captcha image',
    () async {
      final adapter = PassportAdapter(
        (request) => passportResponse(
          request.options.method == 'GET'
              ? '{"_sign":"fixture","location":"/fe/service/login?ticket=fixture-secret"}'
              : '{"code":70016}',
        ),
      );
      final result =
          await client(adapter).login(account: 'account', password: 'password')
              as MiPassportChallenge;
      expect(result.kind, MiChallengeKind.identity);
      expect(result.url.path, '/fe/service/login');
      expect(result.toString(), isNot(contains('fixture-secret')));
      expect(adapter.requests, hasLength(2));
    },
  );

  test('captchaUrl may contain an interactive verification page', () async {
    final adapter = PassportAdapter(
      (request) => passportResponse(
        request.options.method == 'GET'
            ? '{"_sign":"fixture"}'
            : '{"code":87001,"captchaUrl":"/identity/authStart?ticket=fixture"}',
      ),
    );
    final result =
        await client(adapter).login(account: 'account', password: 'password')
            as MiPassportChallenge;
    expect(result.kind, MiChallengeKind.identity);
    expect(adapter.requests, hasLength(2));
  });

  test(
    'octet-stream images load with cookies from same-host redirects',
    () async {
      final adapter = PassportAdapter((request) {
        if (request.options.uri.queryParameters.containsKey('ticket')) {
          return passportImageResponse(imageBytes);
        }
        return ResponseBody.fromString(
          '',
          302,
          headers: {
            'location': ['/pass/getCode?ticket=rotated'],
            'set-cookie': ['ick=rotated-captcha; Path=/pass; Secure; HttpOnly'],
          },
        );
      });
      expect(await client(adapter).captchaImage(challenge), imageBytes);
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.last.cookie, contains('ick=rotated-captcha'));
      expect(adapter.requests.every((r) => !r.options.followRedirects), isTrue);
    },
  );

  for (final body in ['', '<!doctype html><html>fixture-secret</html>']) {
    test(
      'non-image responses produce a redacted retryable error: ${body.isEmpty ? 'empty' : 'HTML'}',
      () async {
        final adapter = PassportAdapter((_) => passportResponse(body));
        await expectLater(
          client(adapter).captchaImage(challenge),
          throwsA(
            isA<ApiFailure>()
                .having(
                  (error) => error.code,
                  'code',
                  'MI_DIRECT_CAPTCHA_INVALID_IMAGE',
                )
                .having(
                  (error) => error.message,
                  'message',
                  isNot(contains('fixture-secret')),
                ),
          ),
        );
      },
    );
  }

  test('redirect cannot send captcha cookies to another host', () async {
    final adapter = PassportAdapter(
      (_) => ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['https://attacker.invalid/pass/getCode'],
          'set-cookie': ['ick=fixture-secret; Path=/pass; Secure'],
        },
      ),
    );
    await expectLater(
      client(adapter).captchaImage(challenge),
      throwsA(isA<ApiFailure>()),
    );
    expect(adapter.requests, hasLength(1));
  });

  test('captcha redirect loops stop after three redirects', () async {
    final adapter = PassportAdapter(
      (_) => ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': ['/pass/getCode'],
        },
      ),
    );
    await expectLater(
      client(adapter).captchaImage(challenge),
      throwsA(isA<ApiFailure>()),
    );
    expect(adapter.requests, hasLength(4));
  });
}
