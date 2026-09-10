import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/async/serial_executor.dart';
import '../../../core/direct/auth/mi_passport_http.dart';
import '../../../core/direct/auth/mi_web_auth_policy.dart';
import '../../../core/direct/auth/mi_web_cookie_bridge.dart';
import '../../../core/direct/auth/mi_web_verifier.dart';
import '../../../core/direct/mi_direct_providers.dart';
import '../data/direct_verification_driver.dart';
import '../models/direct_verification_state.dart';

final directVerificationViewModelProvider = NotifierProvider.autoDispose
    .family<
      DirectVerificationViewModel,
      DirectVerificationState,
      MiWebAuthRequest
    >(DirectVerificationViewModel.new);

class DirectVerificationViewModel extends Notifier<DirectVerificationState> {
  DirectVerificationViewModel(this.request);
  final MiWebAuthRequest request;
  late MiWebCookies _cookies;
  final _captures = SerialExecutor();
  DirectVerificationDriver? _driver;
  bool _prepared = false;
  bool _prefilling = false;
  bool _disposed = false;

  @override
  DirectVerificationState build() {
    _cookies = ref.read(miWebCookiesProvider);
    ref.onDispose(() {
      _disposed = true;
      request.cancel();
      unawaited(_driver?.stop().catchError((Object _) {}));
    });
    return DirectVerificationState(
      loading: !request.cancelled,
      closed: request.cancelled,
    );
  }

  bool get _current =>
      !_disposed && ref.mounted && !state.closed && !request.cancelled;

  Future<void> attach(DirectVerificationDriver driver) async {
    _driver = driver;
    if (request.cancelled) {
      cancel();
      return;
    }
    await _prepareAndLoad();
  }

  Future<void> _prepareAndLoad() async {
    try {
      MiPassportHttp.accountUri(request.url.toString());
      await _cookies.prepare(request.url, request.cookies);
      if (!_current) return;
      _prepared = true;
      await _driver?.load(request.url);
    } catch (_) {
      failed();
    }
  }

  Future<bool> navigate(Uri? uri, {required bool mainFrame}) async {
    if (!_current) return false;
    if (!mainFrame) return true;
    if (MiWebAuthPolicy.isCallback(uri)) {
      await _capture(uri);
      return false;
    }
    if (MiWebAuthPolicy.isAuthEnd(uri)) {
      await _capture(null, requireCredentials: true);
      return _current;
    }
    return MiWebAuthPolicy.isAccount(uri);
  }

  void loading() {
    if (_current) state = const DirectVerificationState();
  }

  Future<void> loaded(Uri? uri) async {
    if (!_current || state.errorMessage != null || uri?.scheme == 'about') {
      return;
    }
    state = const DirectVerificationState(loading: false);
    await visited(uri);
    await _fillLogin(uri);
  }

  Future<void> _fillLogin(Uri? uri) async {
    final prefill = request.prefill;
    if (!_current ||
        _prefilling ||
        prefill == null ||
        prefill.isEmpty ||
        !MiWebAuthPolicy.isAccount(uri)) {
      return;
    }
    _prefilling = true;
    try {
      if (await _driver?.fillLogin(prefill) == true) prefill.clear();
    } catch (_) {
      // 页面变更或导航导致预填不可用时，保留手动输入，不阻断验证。
    } finally {
      _prefilling = false;
    }
  }

  Future<void> visited(Uri? uri) async {
    if (!_current) return;
    if (MiWebAuthPolicy.isCallback(uri)) {
      await _capture(uri);
    } else if (MiWebAuthPolicy.isAuthEnd(uri)) {
      await _capture(null, requireCredentials: true);
    }
  }

  Future<void> _capture(Uri? callback, {bool requireCredentials = false}) =>
      _captures.run(() async {
        if (!_current) return;
        await _readResult(callback, requireCredentials);
      });

  Future<void> _readResult(Uri? callback, bool requireCredentials) async {
    try {
      final account = await _cookies.account();
      if (requireCredentials &&
          ((account['userId']?.isEmpty ?? true) ||
              (account['passToken']?.isEmpty ?? true))) {
        return;
      }
      final service = callback == null
          ? <String, String>{}
          : await _cookies.service(callback);
      if (!_current) return;
      await _driver?.stop();
      if (_current) {
        state = DirectVerificationState(
          loading: false,
          closed: true,
          result: MiWebAuthResult(
            callbackUri: callback,
            accountCookies: account,
            serviceCookies: service,
          ),
        );
      }
    } catch (_) {
      failed();
    }
  }

  Future<void> retry() async {
    if (!_current) return;
    state = const DirectVerificationState();
    if (!_prepared) return _prepareAndLoad();
    try {
      await _driver?.reload();
    } catch (_) {
      failed();
    }
  }

  void failed() {
    if (_current) {
      state = const DirectVerificationState(
        loading: false,
        errorMessage: '验证页面加载失败，请重试',
      );
    }
  }

  void cancel() {
    if (_disposed || !ref.mounted || state.closed) return;
    request.cancel();
    state = const DirectVerificationState(loading: false, closed: true);
  }
}
