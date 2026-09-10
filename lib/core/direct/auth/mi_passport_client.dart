import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../network/api_failure.dart';
import '../../storage/key_value_store.dart';
import 'mi_passport_captcha.dart';
import 'mi_passport_exchange.dart';
import 'mi_passport_http.dart';
import 'mi_passport_result.dart';
import 'mi_passport_web_exchange.dart';
import 'mi_web_login_prefill.dart';
import 'mi_web_verifier.dart';

/// 每次交互登录共享一个 Passport 实例；密码只用于当前请求，不缓存或落盘。
class MiPassportClient {
  MiPassportClient({
    required MiPassportHttp http,
    required KeyValueStore preferences,
    MiWebVerifier? webVerifier,
  }) : _http = http,
       _preferences = preferences,
       _webVerifier = webVerifier;

  final MiPassportHttp _http;
  final KeyValueStore _preferences;
  final MiWebVerifier? _webVerifier;
  int _webGeneration = 0;
  Map<String, dynamic>? _sign;
  String? _account;
  bool _busy = false;
  static const _deviceIdKey = 'hmusic.direct.passportDeviceId';

  Future<MiPassportResult> login({
    required String account,
    required String password,
    String? captchaCode,
  }) => _exclusive(() async {
    if (account.trim().isEmpty || password.isEmpty) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '请填写小米账号和密码',
      );
    }
    if (captchaCode == null || _sign == null || _account != account.trim()) {
      await _start(account.trim());
    }
    final sign = _sign!;
    final response = await _http.request(
      MiPassportHttp.accountUri('/pass/serviceLoginAuth2'),
      form: {
        '_json': 'true',
        'qs': sign['qs']?.toString() ?? '',
        'sid': 'micoapi',
        '_sign': sign['_sign'],
        'callback': sign['callback']?.toString() ?? '',
        'user': account.trim(),
        'hash': md5.convert(utf8.encode(password)).toString().toUpperCase(),
        if (captchaCode != null && captchaCode.isNotEmpty)
          'captCode': captchaCode,
      },
    );
    final data = MiPassportHttp.decode(response.data);
    if (data['code'] == 70016 &&
        data['captchaUrl'] == null &&
        data['notificationUrl'] == null &&
        sign['location'] is String) {
      data['captchaUrl'] = MiPassportHttp.accountUri(
        sign['location'] as String,
      ).toString();
    }
    if (data['code'] != 0 &&
        data['captchaUrl'] == null &&
        data['notificationUrl'] == null) {
      throw const ApiFailure(
        kind: ApiFailureKind.unauthorized,
        code: 'MI_DIRECT_LOGIN_REJECTED',
        message: '小米登录未成功，请检查账号、密码或验证码',
      );
    }
    return _finish(data);
  });

  Future<void> _start(String account) async {
    _sign = null;
    _account = account;
    await _http.cookies.deleteAll();
    var deviceId = await _preferences.getString(_deviceIdKey);
    if (deviceId == null || !RegExp(r'^[A-Z0-9]{16}$').hasMatch(deviceId)) {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final random = Random.secure();
      deviceId = List.generate(
        16,
        (_) => chars[random.nextInt(chars.length)],
      ).join();
      await _preferences.setString(_deviceIdKey, deviceId);
    }
    final uri = MiPassportHttp.accountUri(
      '/pass/serviceLogin?sid=micoapi&_json=true',
    );
    await _http.cookies.saveFromResponse(uri, [
      Cookie('sdkVersion', '3.9')..path = '/',
      Cookie('deviceId', deviceId)..path = '/',
    ]);
    final data = MiPassportHttp.decode((await _http.request(uri)).data);
    if (data['_sign'] is! String || (data['_sign'] as String).isEmpty) {
      throw MiPassportHttp.invalidResponse;
    }
    _sign = data;
  }

  Future<MiPassportResult> loginWithPassToken({
    required String userId,
    required String passToken,
  }) => _exclusive(() => _exchangePassToken(userId, passToken));

  Future<MiPassportResult> _exchangePassToken(
    String userId,
    String passToken,
  ) async {
    if (!_validCookie(userId) || !_validCookie(passToken)) {
      throw MiPassportHttp.invalidResponse;
    }
    _sign = null;
    _account = null;
    await _http.cookies.deleteAll();
    final uri = MiPassportHttp.accountUri(
      '/pass/serviceLogin?sid=micoapi&_json=true',
    );
    final deviceId = await _preferences.getString(_deviceIdKey);
    await _http.cookies.saveFromResponse(uri, [
      Cookie('userId', userId)..path = '/',
      Cookie('passToken', passToken)..path = '/',
      Cookie('sdkVersion', '3.9')..path = '/',
      if (deviceId != null && RegExp(r'^[A-Z0-9]{16}$').hasMatch(deviceId))
        Cookie('deviceId', deviceId)..path = '/',
    ]);
    final data = MiPassportHttp.decode((await _http.request(uri)).data);
    return _finish({
      ...data,
      'userId': data['userId'] ?? userId,
      'passToken': passToken,
    }, allowPassTokenFallback: false);
  }

  Future<Uint8List> captchaImage(MiPassportChallenge challenge) =>
      _exclusive(() async {
        if (challenge.kind != MiChallengeKind.captcha) {
          throw MiPassportHttp.invalidResponse;
        }
        return MiPassportCaptcha(_http).load(challenge.url);
      });

  Future<MiPassportResult?> verifyWeb(
    MiPassportChallenge challenge, {
    MiWebLoginPrefill? prefill,
  }) => _exclusive(() async {
    final verifier = _webVerifier;
    if (verifier == null || challenge.kind != MiChallengeKind.identity) {
      throw MiPassportHttp.invalidResponse;
    }
    final generation = _webGeneration;
    final uri = MiPassportHttp.accountUri(challenge.url.toString());
    final cookies = <String, Cookie>{};
    for (final source in [
      uri,
      MiPassportHttp.accountUri('/pass/serviceLoginAuth2'),
    ]) {
      for (final cookie in await _http.cookies.loadForRequest(source)) {
        cookies['${cookie.domain}/${cookie.path}/${cookie.name}'] = cookie;
      }
    }
    if (generation != _webGeneration) return null;
    final result = await verifier.open(
      url: uri,
      cookies: cookies.values.toList(),
      prefill: prefill,
    );
    if (result == null || generation != _webGeneration) return null;
    final authenticated = await MiPassportWebExchange(_http).finish(
      result,
      exchangePassToken: _exchangePassToken,
      isCurrent: () => generation == _webGeneration,
    );
    if (authenticated == null || generation != _webGeneration) return null;
    return _completeResult(authenticated);
  });

  Future<void> cancelWebVerification() {
    ++_webGeneration;
    return _webVerifier?.cancel() ?? Future<void>.value();
  }

  Future<MiPassportResult> _finish(
    Map<String, dynamic> data, {
    bool allowPassTokenFallback = true,
  }) async {
    final MiPassportResult result;
    try {
      result = await MiPassportExchange(_http).finish(data);
    } on ApiFailure catch (failure) {
      final passToken = data['passToken'];
      final userId = data['userId']?.toString();
      if (allowPassTokenFallback &&
          (failure.code == 'MI_DIRECT_STS_TOKEN_MISSING' ||
              (failure.code == 'MI_DIRECT_STS_REJECTED' &&
                  {400, 401, 403}.contains(failure.statusCode))) &&
          passToken is String &&
          userId != null) {
        return _exchangePassToken(userId, passToken);
      }
      rethrow;
    }
    return _completeResult(result);
  }

  Future<MiPassportResult> _completeResult(MiPassportResult result) async {
    if (result is MiPassportAuthenticated) {
      _sign = null;
      _account = null;
      await _http.cookies.deleteAll();
    }
    return result;
  }

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_busy) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        code: 'MI_DIRECT_LOGIN_BUSY',
        message: '小米登录正在处理中',
      );
    }
    _busy = true;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }

  static bool _validCookie(String value) =>
      value.isNotEmpty && !RegExp(r'[\x00-\x20\x7f;,]').hasMatch(value);

  Future<void> reset() => _exclusive(() async {
    _sign = null;
    _account = null;
    await _http.cookies.deleteAll();
  });

  void close() {
    unawaited(cancelWebVerification().catchError((Object _) {}));
    _http.close();
  }
}
