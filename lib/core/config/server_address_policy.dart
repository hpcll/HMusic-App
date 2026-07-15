import 'dart:io';

import 'build_edition.dart';
import 'server_address_exception.dart';

abstract final class ServerAddressPolicy {
  static Uri normalize(
    String input, {
    bool storeEdition = BuildEdition.isStore,
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const ServerAddressException('请输入 HMusic Server 地址');
    }

    final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      throw const ServerAddressException('服务器地址格式不正确');
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw const ServerAddressException('服务器地址只支持 HTTP 或 HTTPS');
    }
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      throw const ServerAddressException('服务器地址不能包含账号、参数或片段');
    }
    if (uri.path.isNotEmpty && uri.path != '/') {
      throw const ServerAddressException('服务器地址暂不支持子路径部署');
    }
    if (storeEdition && uri.scheme == 'http' && !_isLocal(uri.host)) {
      throw const ServerAddressException('公网服务器必须使用 HTTPS');
    }
    return uri.replace(path: '', query: null, fragment: null);
  }

  static bool _isLocal(String host) {
    final normalized = host.toLowerCase();
    if (normalized == 'localhost' || normalized.endsWith('.local')) return true;

    final address = InternetAddress.tryParse(normalized);
    if (address == null) return false;
    if (address.isLoopback || address.isLinkLocal) return true;

    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      return bytes[0] == 10 ||
          (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
          (bytes[0] == 192 && bytes[1] == 168);
    }
    return bytes.isNotEmpty && (bytes[0] & 0xFE) == 0xFC;
  }
}
