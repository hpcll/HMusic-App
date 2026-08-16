import 'dart:io';

import '../config/server_config_store.dart';
import '../network/api_failure.dart';

typedef HostResolver = Future<List<InternetAddress>> Function(String host);

class StreamUrlRebaser {
  StreamUrlRebaser({
    required ServerConfigStore serverConfigStore,
    HostResolver? resolveHost,
  }) : _serverConfigStore = serverConfigStore,
       _resolveHost =
           resolveHost ??
           ((host) =>
               InternetAddress.lookup(host, type: InternetAddressType.IPv4));

  final ServerConfigStore _serverConfigStore;
  final HostResolver _resolveHost;

  // 已解析过的裸主机名 → IPv4，避免每首歌都查一次 DNS/mDNS。
  final Map<String, String> _resolved = <String, String>{};

  Future<Uri> rebase(String streamUrl) async {
    final serverBase = await _serverConfigStore.read();
    final source = Uri.tryParse(streamUrl);
    if (serverBase == null ||
        source == null ||
        (source.scheme != 'http' && source.scheme != 'https') ||
        !source.path.startsWith('/api/v1/proxy/')) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidResponse,
        message: '服务器返回了无效的音频地址',
      );
    }
    final rebased = serverBase.replace(
      path: source.path,
      query: source.hasQuery ? source.query : null,
    );
    return rebased.replace(host: await _playableHost(rebased.host));
  }

  // 无点号裸主机名（mDNS 发现常给 "mac"）必须换成 IPv4 才能交给平台播放器：
  // dio 走自有 socket 能解析它，但 AVFoundation/CFNetwork 判其不符 ATS 直接拒
  // （NSURLErrorDomain -1008，表现为「音源加载失败」而 API 一切正常）。
  // 解析失败保留原样——让播放器自己报错，胜过在这里把地址改坏。
  Future<String> _playableHost(String host) async {
    if (host.isEmpty || host.contains('.') || host.contains(':')) return host;
    final cached = _resolved[host];
    if (cached != null) return cached;
    try {
      final addresses = await _resolveHost(host);
      if (addresses.isEmpty) return host;
      final address = addresses.first.address;
      _resolved[host] = address;
      return address;
    } on Object {
      return host;
    }
  }
}
