import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/auth/mi_passport_http.dart';
import 'package:hmusic/core/network/api_failure.dart';

import 'support/passport_adapter.dart';

void main() {
  for (final status in [400, 401, 403, 429, 503]) {
    test(
      'HTTP $status retains status without exposing authentication data',
      () async {
        final http = MiPassportHttp(
          adapter: PassportAdapter(
            (_) =>
                passportResponse('fixture-password-and-cookie', status: status),
          ),
        );
        addTearDown(http.close);
        await expectLater(
          http.request(
            Uri.parse('https://api2.mina.mi.com/sts?ticket=fixture-secret'),
          ),
          throwsA(
            isA<ApiFailure>()
                .having((e) => e.statusCode, 'status', status)
                .having((e) => e.details, 'safe phase', {'stage': 'sts'})
                .having(
                  (e) => e.message,
                  'HTTP failure',
                  isNot(contains('检查网络')),
                )
                .having(
                  (e) => e.toString(),
                  'redacted',
                  isNot(contains('fixture')),
                ),
          ),
        );
      },
    );
  }

  for (final type in [
    DioExceptionType.connectionTimeout,
    DioExceptionType.connectionError,
  ]) {
    test('$type remains a connectivity failure', () async {
      final http = MiPassportHttp(
        adapter: PassportAdapter(
          (r) => throw DioException(
            requestOptions: r.options,
            type: type,
            message: 'fixture-secret',
          ),
        ),
      );
      addTearDown(http.close);
      await expectLater(
        http.request(MiPassportHttp.accountUri('/pass/serviceLogin')),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.statusCode, 'no HTTP response', isNull)
              .having(
                (e) => e.kind,
                'kind',
                type == DioExceptionType.connectionTimeout
                    ? ApiFailureKind.timeout
                    : ApiFailureKind.offline,
              )
              .having((e) => e.message, 'network hint', contains('检查网络'))
              .having(
                (e) => e.toString(),
                'redacted',
                isNot(contains('fixture')),
              ),
        ),
      );
    });
  }
}
