import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/auth/mi_passport_client.dart';
import 'package:hmusic/core/direct/auth/mi_passport_http.dart';
import 'package:hmusic/core/direct/auth/mi_passport_result.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/storage/key_value_store.dart';

import 'support/passport_adapter.dart';

const _success =
    '{"code":0,"userId":"123","ssecurity":"security","nonce":12345,"passToken":"fixture-pass","location":"https://api2.mina.mi.com/sts?ticket=fixture"}';

void main() {
  for (final failedStatus in [302, 400, 403]) {
    test(
      'STS $failedStatus without token falls back once without resending password',
      () async {
        var signCalls = 0;
        var stsCalls = 0;
        final adapter = PassportAdapter((r) {
          if (r.options.uri.path == '/pass/serviceLogin') {
            signCalls++;
            return passportResponse(
              signCalls == 1 ? '{"_sign":"fixture"}' : _success,
            );
          }
          if (r.options.uri.path == '/pass/serviceLoginAuth2') {
            return passportResponse(_success);
          }
          stsCalls++;
          return stsCalls == 1
              ? passportResponse('', status: failedStatus)
              : passportResponse(
                  '',
                  status: 302,
                  cookies: ['serviceToken=fixture-token; Path=/'],
                );
        });
        final client = MiPassportClient(
          http: MiPassportHttp(adapter: adapter),
          preferences: MemoryKeyValueStore(),
        );
        addTearDown(client.close);
        expect(
          await client.login(account: 'account', password: 'password'),
          isA<MiPassportAuthenticated>(),
        );
        expect(adapter.requests, hasLength(5));
        expect(
          adapter.requests.where((r) => r.options.method == 'POST'),
          hasLength(1),
        );
        expect(adapter.requests[3].cookie, contains('passToken=fixture-pass'));
      },
    );
  }

  test('failed fallback is bounded and does not recurse', () async {
    final adapter = PassportAdapter((r) {
      if (r.options.uri.path == '/sts') {
        return passportResponse('', status: 302);
      }
      if (r.options.method == 'POST' || r.cookie.contains('passToken=')) {
        return passportResponse(_success);
      }
      return passportResponse('{"_sign":"fixture"}');
    });
    final client = MiPassportClient(
      http: MiPassportHttp(adapter: adapter),
      preferences: MemoryKeyValueStore(),
    );
    addTearDown(client.close);
    await expectLater(
      client.login(account: 'account', password: 'password'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.code,
          'code',
          'MI_DIRECT_STS_TOKEN_MISSING',
        ),
      ),
    );
    expect(adapter.requests, hasLength(5));
  });

  test('legacy captcha location from sign response remains usable', () async {
    final adapter = PassportAdapter(
      (r) => passportResponse(
        r.options.method == 'GET'
            ? '{"_sign":"fixture","location":"/pass/getCode"}'
            : '{"code":70016}',
      ),
    );
    final client = MiPassportClient(
      http: MiPassportHttp(adapter: adapter),
      preferences: MemoryKeyValueStore(),
    );
    addTearDown(client.close);
    final result =
        await client.login(account: 'account', password: 'password')
            as MiPassportChallenge;
    expect(result.url.path, '/pass/getCode');
  });

  test(
    'device identity persists across client recreation without persisting secrets',
    () async {
      final preferences = MemoryKeyValueStore();
      final adapter = PassportAdapter(
        (r) => passportResponse(
          r.options.method == 'GET' ? '{"_sign":"fixture"}' : '{"code":70016}',
        ),
      );
      for (var i = 0; i < 2; i++) {
        final client = MiPassportClient(
          http: MiPassportHttp(adapter: adapter),
          preferences: preferences,
        );
        await expectLater(
          client.login(account: 'account', password: 'secret-password'),
          throwsA(isA<ApiFailure>()),
        );
        client.close();
      }
      expect(adapter.requests[0].cookie, adapter.requests[2].cookie);
      expect(adapter.requests[0].cookie, matches(r'deviceId=[A-Z0-9]{16}'));
      expect(await preferences.getString('hmusic.direct.micoSession'), isNull);
    },
  );
}
