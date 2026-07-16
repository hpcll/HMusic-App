import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

// 安全存储 + 进程内缓存。持久层仍是 Keychain/Keystore（铁律 4），但 token
// 首次读到/写入后驻留内存：运行期请求不再逐次碰钥匙串——macOS 锁屏、休眠
// 或重编译后钥匙串会拒绝静默访问（-25308 errSecInteractionNotAllowed），
// 曾把 3s 周期上报和播完 ended 推进整条打崩（表现为「播完不接下一首」）。
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'hmusic.accessToken';

  final FlutterSecureStorage _storage;
  String? _cached;
  bool _cacheLoaded = false;

  @override
  Future<String?> read() async {
    if (_cacheLoaded) return _cached;
    _cached = await _storage.read(key: _tokenKey);
    _cacheLoaded = true;
    return _cached;
  }

  @override
  Future<void> write(String token) async {
    // 先落内存：钥匙串暂不可写时本次会话仍可用，重启后自然回到登录页。
    _cached = token;
    _cacheLoaded = true;
    await _storage.write(key: _tokenKey, value: token);
  }

  @override
  Future<void> clear() async {
    _cached = null;
    _cacheLoaded = true;
    await _storage.delete(key: _tokenKey);
  }
}
