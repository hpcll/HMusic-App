import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/mi_direct_session.dart';
import 'package:hmusic/core/direct/mi_mina_client.dart';
import 'package:hmusic/core/network/api_failure.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final bytes = <int>[];
    if (stream != null) {
      await for (final chunk in stream) {
        bytes.addAll(chunk);
      }
    }
    bodies.add(utf8.decode(bytes));
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, [int status = 200]) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

void main() {
  final session = MiDirectSession(userId: '123', serviceToken: 'secret-test');

  test('device discovery uses Xiaomi cookies with no Server Bearer', () async {
    final adapter = _Adapter(
      (_) => _json('''{"code":0,"data":[
      {"deviceID":"mina-1","miotDID":42,"alias":"Living room","hardware":"OH2P","localIp":"192.168.1.8"},
      {"deviceID":"","miotDID":"43"}
    ]}'''),
    );
    final client = MiMinaClient(adapter: adapter);
    addTearDown(client.close);
    final devices = await client.devices(session);
    expect(devices.single.id, 'mina-1');
    expect(devices.single.did, '42');
    expect(devices.single.profile.supportsSeek, isFalse);
    final request = adapter.requests.single;
    expect(request.uri.host, 'api.mina.mi.com');
    expect(request.headers['Cookie'], session.cookie);
    expect(request.headers.containsKey('Authorization'), isFalse);
    expect(request.followRedirects, isFalse);
  });

  test(
    'ubus serializes its message as form JSON and never retries errors',
    () async {
      final adapter = _Adapter((_) => _json('{"code":500,"data":null}'));
      final client = MiMinaClient(adapter: adapter);
      addTearDown(client.close);
      await expectLater(
        client.ubus(
          session,
          deviceId: 'speaker',
          method: 'player_play_operation',
          message: {'action': 'pause'},
        ),
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'MI_DIRECT_REJECTED'),
        ),
      );
      final request = adapter.requests.single;
      expect(request.contentType, Headers.formUrlEncodedContentType);
      final form = Uri.splitQueryString(adapter.bodies.single);
      expect(form['message'], '{"action":"pause"}');
      expect(form['path'], 'mediaplayer');
    },
  );

  for (final status in [200, 401]) {
    test(
      'HTTP $status with Xiaomi 401 maps only to direct session expiry',
      () async {
        final adapter = _Adapter((_) => _json('{"code":401}', status));
        final client = MiMinaClient(adapter: adapter);
        addTearDown(client.close);
        await expectLater(
          client.devices(session),
          throwsA(
            isA<ApiFailure>()
                .having((e) => e.code, 'code', 'MI_DIRECT_SESSION_EXPIRED')
                .having(
                  (e) => e.details,
                  'no credential-bearing exception',
                  isNull,
                ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      },
    );
  }

  test(
    'invalid payload is an error rather than a false empty device list',
    () async {
      final adapter = _Adapter((_) => _json('{"code":0,"data":{}}'));
      final client = MiMinaClient(adapter: adapter);
      addTearDown(client.close);
      await expectLater(
        client.devices(session),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    },
  );
}
