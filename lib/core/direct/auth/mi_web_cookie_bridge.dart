import 'dart:io' as io;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../async/serial_executor.dart';
import 'mi_passport_http.dart';

abstract interface class MiWebCookies {
  Future<void> prepare(Uri url, List<io.Cookie> cookies);
  Future<Map<String, String>> account();
  Future<Map<String, String>> service(Uri uri);
  Future<void> clear();
}

/// 本 App 只将此 WebView Cookie 存储用于小米验证，与 Safari 的存储互相隔离。
class MiWebCookieBridge implements MiWebCookies {
  final CookieManager _cookies = CookieManager.instance();
  final _writes = SerialExecutor();
  static final accountUrl = WebUri(
    '${MiPassportHttp.accountBase}/pass/serviceLogin',
  );

  @override
  Future<void> prepare(Uri url, List<io.Cookie> cookies) =>
      _writes.run(() async {
        await _cookies.deleteAllCookies();
        for (final cookie in cookies) {
          final saved = await _cookies.setCookie(
            url: WebUri.uri(url),
            name: cookie.name,
            value: cookie.value,
            domain: cookie.domain ?? url.host,
            path: cookie.path ?? '/',
            isSecure: true,
            isHttpOnly: cookie.httpOnly,
            expiresDate: cookie.expires?.millisecondsSinceEpoch,
            maxAge: cookie.maxAge,
          );
          if (!saved) throw MiPassportHttp.invalidResponse;
        }
      });

  @override
  Future<Map<String, String>> account() => _read(accountUrl);

  @override
  Future<Map<String, String>> service(Uri uri) => _read(WebUri.uri(uri));

  Future<Map<String, String>> _read(WebUri uri) async => {
    for (final cookie in await _cookies.getCookies(url: uri))
      if (cookie.value is String &&
          {
            'userId',
            'passToken',
            'serviceToken',
            'ssecurity',
          }.contains(cookie.name))
        cookie.name: cookie.value as String,
  };

  // 取消时也必须等 Cookie 注入结束，避免清理后又被迟到的写入污染。
  @override
  Future<void> clear() => _writes.run(() async {
    await _cookies.deleteAllCookies();
  });
}
