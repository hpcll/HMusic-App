import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

// 安全存储 + 进程内缓存。持久层仍是 Keychain/Keystore（铁律 4），但 token
// 首次读到/写入后驻留内存：运行期请求不再逐次碰钥匙串——macOS 锁屏、休眠
// 或重编译后钥匙串会拒绝静默访问（-25308 errSecInteractionNotAllowed），
// 曾把 3s 周期上报和播完 ended 推进整条打崩（表现为「播完不接下一首」）。
//
// 平台通道整条失效时（插件注册失败的机型，与 core/storage 里 preferences 降级
// 同源）也只降级不抛：内存缓存就是本次会话的真相，重启后回登录页。曾有用户
// 卡在登录页的「处理中…」不动——异常正是从 write() 逃出去，把提交态永久留住。
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
    try {
      _cached = await _storage.read(key: _tokenKey);
    } on Object catch (error) {
      if (!_isStorageFailure(error)) rethrow;
      // 读不到按「没登录」处理：用户重登一次即可，比抛异常打断调用方好。
      debugPrint('[SecureTokenStore] 读取失败，按未登录处理：$error');
      _cached = null;
    }
    _cacheLoaded = true;
    return _cached;
  }

  @override
  Future<void> write(String token) async {
    // 先落内存：钥匙串暂不可写时本次会话仍可用，重启后自然回到登录页。
    _cached = token;
    _cacheLoaded = true;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } on Object catch (error) {
      if (!_isStorageFailure(error)) rethrow;
      debugPrint('[SecureTokenStore] 写入失败，本次会话仅驻留内存：$error');
    }
  }

  @override
  Future<void> clear() async {
    _cached = null;
    _cacheLoaded = true;
    try {
      await _storage.delete(key: _tokenKey);
    } on Object catch (error) {
      if (!_isStorageFailure(error)) rethrow;
      // 删不掉也要当已登出：内存已清，后续请求不再带旧凭据。
      debugPrint('[SecureTokenStore] 清除失败，仅清内存缓存：$error');
    }
  }

  // 只兜平台层故障（通道没处理器、钥匙串拒绝访问、插件缺失），
  // 其它异常照原样抛出，不掩盖真问题。
  static bool _isStorageFailure(Object error) =>
      error is PlatformException || error is MissingPluginException;
}
