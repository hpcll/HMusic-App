import 'dart:typed_data';

import '../network/api_failure.dart';
import 'auth/mi_direct_login_result.dart';
import 'auth/mi_passport_client.dart';
import 'auth/mi_passport_result.dart';
import 'auth/mi_web_login_prefill.dart';
import 'mi_direct_account.dart';
import 'mi_direct_session.dart';
import 'mi_direct_session_store.dart';
import 'mi_mina_client.dart';

export 'mi_direct_account.dart';

/// 会话导入必须通过设备列表真校验；网络失败不覆盖已保存的会话。
class MiDirectAccountRepository {
  MiDirectAccountRepository({
    required MiMinaClient client,
    required MiDirectSessionStore store,
    MiPassportClient? passport,
  }) : _client = client,
       _store = store,
       _passport = passport;

  final MiMinaClient _client;
  final MiDirectSessionStore _store;
  final MiPassportClient? _passport;
  int _generation = 0;
  Future<void> _pending = Future<void>.value();
  MiDirectAccount? cachedAccount;
  MiDirectSession? _expiredSession;

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<MiDirectAccount> importSession(MiDirectSession session) {
    final generation = _generation;
    return _serial(() => _accept(session, generation));
  }

  Future<MiDirectAccount> _accept(
    MiDirectSession session,
    int generation,
  ) async {
    _requireCurrent(generation);
    final devices = await _client.devices(session);
    _requireCurrent(generation);
    await _store.write(session);
    _requireCurrent(generation);
    _expiredSession = null;
    return cachedAccount = MiDirectAccount(
      userId: session.userId,
      devices: devices,
    );
  }

  Future<MiDirectLoginResult> loginPassword({
    required String account,
    required String password,
    String? captchaCode,
  }) {
    final generation = _generation;
    return _serial(() async {
      _requireCurrent(generation);
      return _loginResult(
        await _auth.login(
          account: account,
          password: password,
          captchaCode: captchaCode,
        ),
        generation,
      );
    });
  }

  Future<MiDirectLoginResult> loginPassToken({
    required String userId,
    required String passToken,
  }) {
    final generation = _generation;
    return _serial(() async {
      _requireCurrent(generation);
      return _loginResult(
        await _auth.loginWithPassToken(userId: userId, passToken: passToken),
        generation,
      );
    });
  }

  Future<MiDirectLoginResult> _loginResult(
    MiPassportResult result,
    int generation,
  ) async {
    _requireCurrent(generation);
    return switch (result) {
      MiPassportChallenge() => MiDirectLoginChallenge(result),
      MiPassportAuthenticated(:final session) => MiDirectLoginAuthenticated(
        await _accept(session, generation),
      ),
    };
  }

  Future<Uint8List> captchaImage(MiPassportChallenge challenge) =>
      _serial(() => _auth.captchaImage(challenge));

  Future<MiDirectLoginResult?> verifyWeb(
    MiPassportChallenge challenge, {
    MiWebLoginPrefill? prefill,
  }) {
    final generation = _generation;
    return _serial(() async {
      _requireCurrent(generation);
      final result = await _auth.verifyWeb(challenge, prefill: prefill);
      _requireCurrent(generation);
      return result == null ? null : _loginResult(result, generation);
    });
  }

  MiPassportClient get _auth =>
      _passport ??
      (throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '小米登录服务尚未初始化',
      ));

  void _requireCurrent(int generation) {
    if (_generation != generation) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        code: 'MI_DIRECT_LOGIN_CANCELLED',
        message: '此登录请求已取消',
      );
    }
  }

  Future<MiDirectAccount?> restore() => _serial(() async {
    final session = await _store.read();
    if (session == null) {
      cachedAccount = null;
      return null;
    }
    try {
      return cachedAccount = MiDirectAccount(
        userId: session.userId,
        devices: await _client.devices(session),
      );
    } on ApiFailure catch (failure) {
      if (failure.code == 'MI_DIRECT_SESSION_EXPIRED') {
        await _store.clear();
        cachedAccount = null;
        _expiredSession = session;
      }
      rethrow;
    }
  });

  Future<void> logout() {
    ++_generation;
    final closing = _passport?.cancelWebVerification();
    return _serial(() async {
      await closing;
      await _passport?.reset();
      await _store.clear();
      cachedAccount = null;
      _expiredSession = null;
    });
  }

  Future<void> cancelLogin() {
    ++_generation;
    final closing = _passport?.cancelWebVerification();
    return _serial(() async {
      await closing;
      await _passport?.reset();
    });
  }

  Future<MiDirectSession> session() => _serial(() async {
    final session = await _store.read();
    if (session != null) return session;
    throw const ApiFailure(
      kind: ApiFailureKind.unauthorized,
      code: 'MI_DIRECT_SESSION_EXPIRED',
      message: '请先登录小米账号',
    );
  });

  Future<String?> storedUserId() =>
      _serial(() async => (await _store.read())?.userId);

  /// 迟到的旧请求不能清除刚登录的新会话。
  Future<bool> expire(MiDirectSession rejected) => _serial(() async {
    final current = await _store.read();
    if (current == null &&
        _expiredSession?.serviceToken == rejected.serviceToken &&
        _expiredSession?.userId == rejected.userId) {
      _expiredSession = null;
      return true;
    }
    if (current?.serviceToken != rejected.serviceToken ||
        current?.userId != rejected.userId) {
      return false;
    }
    ++_generation;
    await _store.clear();
    cachedAccount = null;
    _expiredSession = null;
    return true;
  });
}
