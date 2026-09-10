import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'mi_direct_session.dart';

abstract interface class MiDirectSessionStore {
  Future<MiDirectSession?> read();
  Future<void> write(MiDirectSession session);
  Future<void> clear();
}

class SecureMiDirectSessionStore implements MiDirectSessionStore {
  SecureMiDirectSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const key = 'hmusic.direct.micoSession';
  final FlutterSecureStorage _storage;
  MiDirectSession? _cached;
  bool _loaded = false;
  Future<void> _pending = Future<void>.value();

  // 安全存储读写也串行，避免慢写在登出删除之后完成而复活磁盘凭据。
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  @override
  Future<MiDirectSession?> read() => _serial(() async {
    if (_loaded) return _cached;
    final value = await _storage.read(key: key);
    MiDirectSession? session;
    if (value != null) {
      try {
        final data = jsonDecode(value);
        if (data is Map<String, dynamic>) {
          session = MiDirectSession.fromJson(data);
        }
      } on FormatException {
        session = null;
      } on TypeError {
        session = null;
      }
    }
    _cached = session;
    _loaded = true;
    return session;
  });

  @override
  Future<void> write(MiDirectSession session) => _serial(() async {
    await _storage.write(key: key, value: jsonEncode(session.toJson()));
    _cached = session;
    _loaded = true;
  });

  @override
  Future<void> clear() => _serial(() async {
    _cached = null;
    _loaded = true;
    // 删除失败必须向调用者报告，不能声称已持久退出而下次启动恢复旧凭据。
    await _storage.delete(key: key);
  });
}
