import 'dart:io';

import '../../network/api_failure.dart';
import 'mi_web_login_prefill.dart';

/// 只展示本次小米验证并返回结果；不保存账号、不读取系统浏览器会话。
abstract interface class MiWebVerifier {
  Future<MiWebAuthResult?> open({
    required Uri url,
    required List<Cookie> cookies,
    MiWebLoginPrefill? prefill,
  });

  Future<void> cancel();
}

class MiWebAuthRequest {
  MiWebAuthRequest({
    required this.url,
    required List<Cookie> cookies,
    this.prefill,
  }) : cookies = List.unmodifiable(cookies);
  final Uri url;
  final List<Cookie> cookies;
  final MiWebLoginPrefill? prefill;
  bool _cancelled = false;
  bool get cancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    prefill?.clear();
  }

  @override
  String toString() => 'MiWebAuthRequest(redacted)';
}

class UnavailableMiWebVerifier implements MiWebVerifier {
  const UnavailableMiWebVerifier();

  @override
  Future<MiWebAuthResult?> open({
    required Uri url,
    required List<Cookie> cookies,
    MiWebLoginPrefill? prefill,
  }) async {
    throw const ApiFailure(
      kind: ApiFailureKind.invalidConfiguration,
      message: '小米验证页面尚未就绪，请重新打开登录页',
    );
  }

  @override
  Future<void> cancel() async {}
}

class MiWebAuthResult {
  MiWebAuthResult({
    this.callbackUri,
    Map<String, String> accountCookies = const {},
    Map<String, String> serviceCookies = const {},
  }) : accountCookies = Map.unmodifiable(accountCookies),
       serviceCookies = Map.unmodifiable(serviceCookies);

  final Uri? callbackUri;
  final Map<String, String> accountCookies;
  final Map<String, String> serviceCookies;

  @override
  String toString() => 'MiWebAuthResult(redacted)';
}
