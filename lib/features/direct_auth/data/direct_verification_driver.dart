import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/direct/auth/mi_web_login_prefill.dart';
import 'mi_login_prefill_script.dart';

abstract interface class DirectVerificationDriver {
  Future<void> load(Uri uri);
  Future<void> reload();
  Future<void> stop();
  Future<bool> fillLogin(MiWebLoginPrefill prefill);
}

class InAppVerificationDriver implements DirectVerificationDriver {
  const InAppVerificationDriver(this.controller);
  final InAppWebViewController controller;
  @override
  Future<void> load(Uri uri) =>
      controller.loadUrl(urlRequest: URLRequest(url: WebUri.uri(uri)));
  @override
  Future<void> reload() => controller.reload();
  @override
  Future<void> stop() => controller.stopLoading();

  @override
  Future<bool> fillLogin(MiWebLoginPrefill prefill) async {
    if (prefill.isEmpty) return false;
    final result = await controller.callAsyncJavaScript(
      functionBody: miLoginPrefillScript,
      arguments: {'account': prefill.account, 'password': prefill.password},
    );
    return result?.value == true;
  }
}
