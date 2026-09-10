import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/direct/auth/mi_web_cookie_bridge.dart';
import '../../core/direct/auth/mi_web_login_prefill.dart';
import '../../core/direct/auth/mi_web_verifier.dart';
import '../../core/network/api_failure.dart';
import '../../features/direct_auth/views/direct_verification_page.dart';

/// 导航属于 App 装配层；Passport 只依赖验证接口，不依赖页面或 BuildContext。
class RoutedMiWebVerifier implements MiWebVerifier {
  RoutedMiWebVerifier(this._router, {required MiWebCookies cookies})
    : _cookies = cookies;
  final GoRouter Function() _router;
  final MiWebCookies _cookies;
  MiWebAuthRequest? _active;

  @override
  Future<MiWebAuthResult?> open({
    required Uri url,
    required List<Cookie> cookies,
    MiWebLoginPrefill? prefill,
  }) async {
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform)) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '此平台暂不支持 App 内小米验证，请使用已有的小米凭据导入',
      );
    }
    if (_active != null) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '小米验证页面已打开',
      );
    }
    final request = MiWebAuthRequest(
      url: url,
      cookies: cookies,
      prefill: prefill,
    );
    _active = request;
    try {
      return await _router().push<MiWebAuthResult>(
        DirectVerificationPage.path,
        extra: request,
      );
    } finally {
      request.cancel();
      // 验证路由没有退场动画；先销毁内嵌 WebView，再清理它的临时 Cookie。
      await WidgetsBinding.instance.endOfFrame;
      try {
        await _cookies.clear();
      } finally {
        if (identical(_active, request)) _active = null;
      }
    }
  }

  @override
  Future<void> cancel() async {
    final request = _active;
    if (request == null) return;
    request.cancel();
    // push 可能仍在建立路由；等待本帧后再检查，不能漏掉创建期间的取消。
    await WidgetsBinding.instance.endOfFrame;
    final router = _router();
    if (identical(router.state.extra, request) && router.canPop()) router.pop();
  }
}
