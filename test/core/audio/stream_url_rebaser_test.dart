import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/stream_url_rebaser.dart';
import 'package:hmusic/core/config/server_config_store.dart';
import 'package:hmusic/core/network/api_failure.dart';

class _FakeServerConfigStore implements ServerConfigStore {
  _FakeServerConfigStore(this._base);

  final String _base;

  @override
  Future<Uri?> read() async => Uri.parse(_base);

  @override
  Future<void> write(Uri base) async {}

  @override
  Future<void> clear() async {}
}

StreamUrlRebaser _rebaser(
  String base, {
  HostResolver? resolveHost,
  List<String>? lookedUp,
}) {
  return StreamUrlRebaser(
    serverConfigStore: _FakeServerConfigStore(base),
    resolveHost:
        resolveHost ??
        (host) async {
          lookedUp?.add(host);
          return <InternetAddress>[InternetAddress('192.168.1.4')];
        },
  );
}

void main() {
  test('裸主机名换成 IPv4：AVFoundation 对无点号 host 判 ATS 不合规(-1008)', () async {
    final lookedUp = <String>[];
    final rebaser = _rebaser('http://mac:6650', lookedUp: lookedUp);

    final uri = await rebaser.rebase(
      'http://127.0.0.1:6650/api/v1/proxy/local/local:abc.sig',
    );

    expect(
      uri.toString(),
      'http://192.168.1.4:6650/api/v1/proxy/local/local:abc.sig',
    );
    expect(lookedUp, <String>['mac']);
  });

  test('同一裸主机名只解析一次（每首歌都查 DNS 太浪费）', () async {
    final lookedUp = <String>[];
    final rebaser = _rebaser('http://mac:6650', lookedUp: lookedUp);

    await rebaser.rebase('http://127.0.0.1:6650/api/v1/proxy/audio/a.sig');
    await rebaser.rebase('http://127.0.0.1:6650/api/v1/proxy/audio/b.sig');

    expect(lookedUp, <String>['mac']);
  });

  test('IP 与带点域名原样保留，不做解析', () async {
    final lookedUp = <String>[];
    final rebaser = _rebaser('http://192.168.1.9:6650', lookedUp: lookedUp);

    final uri = await rebaser.rebase(
      'http://127.0.0.1:6650/api/v1/proxy/audio/x.sig',
    );

    expect(uri.host, '192.168.1.9');
    expect(lookedUp, isEmpty);
  });

  test('解析失败保留原主机名：让播放器如实报错，不把地址改坏', () async {
    final rebaser = _rebaser(
      'http://mac:6650',
      resolveHost: (_) async => throw const SocketException('no dns'),
    );

    final uri = await rebaser.rebase(
      'http://127.0.0.1:6650/api/v1/proxy/audio/x.sig',
    );

    expect(uri.host, 'mac');
  });

  test('非代理路径一律拒收（不信任服务端返回的任意地址）', () async {
    final rebaser = _rebaser('http://mac:6650');

    await expectLater(
      rebaser.rebase('http://evil.example.com/hack.mp3'),
      throwsA(isA<ApiFailure>()),
    );
  });
}
