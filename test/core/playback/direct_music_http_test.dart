import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/music/direct_music_http.dart';
import 'package:hmusic/core/network/api_failure.dart';

class _PendingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final response = Completer<ResponseBody>();
  final cancelled = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    unawaited(
      cancelFuture?.then((_) {
        if (!cancelled.isCompleted) cancelled.complete();
      }),
    );
    return response.future;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _PendingAdapter adapter;
  late DirectMusicHttp http;

  setUp(() {
    adapter = _PendingAdapter();
    http = DirectMusicHttp(adapter: adapter);
  });
  tearDown(() => http.close());

  test(
    'total deadline cancels the underlying request with a safe error',
    () async {
      await expectLater(
        http.text(
          'https://fixture.example/chart?secret=private-value',
          timeout: const Duration(milliseconds: 30),
        ),
        throwsA(
          isA<ApiFailure>()
              .having((failure) => failure.kind, 'kind', ApiFailureKind.timeout)
              .having(
                (failure) => failure.code,
                'code',
                'DIRECT_MUSIC_REQUEST_FAILED',
              )
              .having(
                (failure) => failure.message,
                'message',
                isNot(contains('private-value')),
              ),
        ),
      );
      await adapter.cancelled.future.timeout(const Duration(seconds: 1));
      expect(adapter.requests, hasLength(1));
      adapter.response.complete(ResponseBody.fromString('late response', 200));
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('successful requests with a deadline are not cancelled later', () async {
    adapter.response.complete(ResponseBody.fromString('chart', 200));
    expect(
      await http.text(
        'https://fixture.example/chart',
        timeout: const Duration(milliseconds: 30),
      ),
      'chart',
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(adapter.cancelled.isCompleted, isFalse);
    expect(
      adapter.requests.single.headers.keys.map((key) => key.toLowerCase()),
      isNot(contains('authorization')),
    );
    expect(
      adapter.requests.single.headers.keys.map((key) => key.toLowerCase()),
      isNot(contains('cookie')),
    );
  });

  test(
    'requests without a custom deadline keep the ordinary transport contract',
    () async {
      final pending = http.text('https://fixture.example/chart');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(adapter.cancelled.isCompleted, isFalse);
      adapter.response.complete(
        ResponseBody.fromString('ordinary response', 200),
      );
      expect(await pending, 'ordinary response');
    },
  );
}
