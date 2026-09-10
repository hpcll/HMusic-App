import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

const lxFixtureScript = r'''
let count = 0;
lx.on(lx.EVENT_NAMES.request, async ({ source, action, info }) => {
  if (info.reject) throw new Error('fixture rejection');
  if (info.hang) return new Promise(() => {});
  if (info.busy) {
    const until = Date.now() + info.busy;
    while (Date.now() < until) {}
  }
  if (info.delay) await new Promise(resolve => setTimeout(resolve, info.delay));
  const { buffer, crypto } = lx.utils;
  const digest = crypto.md5(Buffer.from('abc'));
  const aes = crypto.aesEncrypt(
    Buffer.from('00112233445566778899aabbccddeeff', 'hex'),
    'aes-128-ecb', Buffer.from('000102030405060708090a0b0c0d0e0f', 'hex'));
  const result = {
    name: lx.currentScriptInfo.name, count: ++count, source, action,
    digest, aes: buffer.bufToString(aes, 'hex'),
    text: Buffer.from(new Uint8Array([97, 98, 99]).buffer).toString(),
    randomLength: crypto.randomBytes(16).length,
  };
  if (!info.url) return result;
  return new Promise((resolve, reject) => {
    lx.request(info.url, {
      method: 'POST', form: { digest, title: '测试曲目' },
      headers: { 'X-Lx-Fixture': lx.currentScriptInfo.name },
    }, (error, response, body) => {
      if (error) return reject(error);
      resolve({ ...result, status: response.statusCode, url: body.url });
    });
  });
});
lx.send(lx.EVENT_NAMES.inited, { status: true, sources: {
  wy: { name: 'fixture', actions: ['musicUrl', 'lyric'], qualitys: ['128k', '320k'] },
}});
''';

class LxFixtureAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<Map<String, String>> forms = [];
  Completer<void>? gate;
  bool cancelled = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final part in requestStream) {
        bytes.addAll(part);
      }
    }
    forms.add(Uri.splitQueryString(utf8.decode(bytes)));
    if (gate != null) {
      await Future.any([
        gate!.future,
        if (cancelFuture != null) cancelFuture.then((_) => cancelled = true),
      ]);
    }
    return ResponseBody.fromString(
      jsonEncode({'url': 'https://audio.example/fixture.mp3'}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
