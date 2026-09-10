import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../async/serial_executor.dart';
import '../../network/api_failure.dart';
import 'direct_audio_policy.dart';
import 'direct_resolved_audio.dart';

/// 只代理已解析的音频令牌；流式转发 Range/206，不接受 URL 查询参数。
class DirectAudioProxy {
  HttpServer? _server;
  HttpClient _client = _newClient();
  final SerialExecutor _serial = SerialExecutor();
  bool _disposed = false;
  final Map<String, DirectResolvedAudio> _streams = {};
  final Map<String, DateTime> _expires = {};

  Future<Uri> address(
    DirectResolvedAudio audio, {
    bool remote = false,
    String? deviceIp,
    String? advertisedHost,
    bool qqDirect = false,
  }) => _serial.run(() async {
    if (_disposed) throw StateError('Audio proxy is disposed');
    // AVFoundation 限制公网明文 HTTP，本机通过 loopback 代理使用同一音频链路。
    final localHttp = !remote && audio.uri.scheme == 'http';
    if (!localHttp &&
        !DirectAudioPolicy.needsProxy(audio, qqDirect: qqDirect)) {
      return audio.uri;
    }
    _server ??= await _listen();
    final host = remote
        ? await _lanAddress(deviceIp, advertisedHost)
        : '127.0.0.1';
    final random = Random.secure();
    final token = base64Url
        .encode(List.generate(24, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    final now = DateTime.now();
    for (final key
        in _expires.keys
            .where((key) => _expires[key]!.isBefore(now))
            .toList()) {
      _streams.remove(key);
      _expires.remove(key);
    }
    while (_streams.length >= 128) {
      final oldest = _streams.keys.first;
      _streams.remove(oldest);
      _expires.remove(oldest);
    }
    _streams[token] = audio;
    _expires[token] = now.add(const Duration(hours: 6));
    return Uri(
      scheme: 'http',
      host: host,
      port: _server!.port,
      path: '/audio/$token',
    );
  });

  static HttpClient _newClient() => HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = const Duration(seconds: 15);

  Future<HttpServer> _listen() async {
    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      0,
      shared: false,
    );
    server.listen(
      (request) => unawaited(_serve(request).catchError((Object _) {})),
    );
    return server;
  }

  Future<void> _serve(HttpRequest request) async {
    final token = request.uri.pathSegments.lastOrNull;
    final audio = _streams[token];
    if (!['GET', 'HEAD'].contains(request.method) ||
        request.uri.query.isNotEmpty ||
        request.uri.pathSegments.length != 2 ||
        request.uri.pathSegments.first != 'audio' ||
        audio == null ||
        _expires[token]!.isBefore(DateTime.now())) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    try {
      final upstream = await _client.openUrl(request.method, audio.uri);
      upstream.headers.set('accept-encoding', 'identity');
      upstream.followRedirects = true;
      upstream.maxRedirects = 3;
      for (final header in DirectAudioPolicy.headers(audio).entries) {
        if (![
          'host',
          'connection',
          'content-length',
        ].contains(header.key.toLowerCase())) {
          upstream.headers.set(header.key, header.value);
        }
      }
      for (final name in ['range', 'if-range']) {
        final value = request.headers.value(name);
        if (value != null) upstream.headers.set(name, value);
      }
      final response = await upstream.close().timeout(
        const Duration(seconds: 15),
      );
      request.response.statusCode = response.statusCode;
      for (final name in [
        'content-type',
        'content-length',
        'content-encoding',
        'content-range',
        'accept-ranges',
        'etag',
        'last-modified',
      ]) {
        final value = response.headers.value(name);
        if (value != null) request.response.headers.set(name, value);
      }
      if (request.method == 'HEAD') {
        await response.drain<void>();
      } else {
        await request.response.addStream(response);
      }
    } catch (_) {
      try {
        request.response.statusCode = HttpStatus.badGateway;
      } catch (_) {
        /* 响应头可能已经发出。 */
      }
    } finally {
      await request.response.close().catchError((Object _) {});
    }
  }

  Future<String> _lanAddress(String? deviceIp, String? advertisedHost) async {
    if (advertisedHost != null && advertisedHost.trim().isNotEmpty) {
      final address = InternetAddress.tryParse(advertisedHost.trim());
      if (address != null &&
          !address.isLoopback &&
          !address.isMulticast &&
          address.address != '0.0.0.0' &&
          address.type == InternetAddressType.IPv4) {
        return address.address;
      }
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '请填写音箱可访问的本机局域网 IPv4 地址',
      );
    }
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    final addresses = interfaces
        .expand((interface) => interface.addresses)
        .where((address) => !address.isLoopback && _private(address.address))
        .toList();
    final subnet = deviceIp?.split('.').take(3).join('.');
    final sameNetwork = addresses
        .where(
          (address) => address.address.split('.').take(3).join('.') == subnet,
        )
        .firstOrNull;
    final selected = sameNetwork ?? addresses.firstOrNull;
    if (selected != null) return selected.address;
    throw const ApiFailure(
      kind: ApiFailureKind.invalidConfiguration,
      message: '该音源需要本机代理，请将手机与音箱连接到同一局域网',
    );
  }

  bool _private(String host) {
    final parts = host.split('.').map(int.tryParse).toList();
    return parts.length == 4 &&
        (parts[0] == 10 ||
            (parts[0] == 192 && parts[1] == 168) ||
            (parts[0] == 172 &&
                parts[1] != null &&
                parts[1]! >= 16 &&
                parts[1]! <= 31));
  }

  Future<void> close() => _serial.run(_close);

  Future<void> _close() async {
    final server = _server;
    _server = null;
    _streams.clear();
    _expires.clear();
    await server?.close(force: true);
    _client.close(force: true);
    if (!_disposed) _client = _newClient();
  }

  Future<void> dispose() => _serial.run(() async {
    _disposed = true;
    await _close();
  });
}
