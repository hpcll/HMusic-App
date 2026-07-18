import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// mDNS 候选源：订阅服务端广播的 _hmusic._tcp（Server 经 bonjour-service
// 发布），解析出 host:port 组成候选 base。这里只递候选不定身份——确认统一
// 走 /system/info 探测（TXT 可伪造/过期；解析结果按平台可能是 IP 或
// .local 主机名，交给 HTTP 层解析即可）。
const String _serviceType = '_hmusic._tcp';

// 一轮订阅窗口：局域网 mDNS 通常亚秒应答，4s 足够收齐并容忍慢应答。
const Duration _window = Duration(seconds: 4);

final Provider<Stream<Uri> Function()> mdnsCandidatesProvider =
    Provider<Stream<Uri> Function()>((ref) => _discoverCandidates);

Stream<Uri> _discoverCandidates() {
  final controller = StreamController<Uri>();
  unawaited(_pumpDiscovery(controller));
  return controller.stream;
}

Future<void> _pumpDiscovery(StreamController<Uri> controller) async {
  BonsoirDiscovery? discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? subscription;
  try {
    discovery = BonsoirDiscovery(type: _serviceType);
    await discovery.initialize();
    subscription = discovery.eventStream?.listen((event) {
      final service = event.service;
      if (service == null) return;
      if (event is BonsoirDiscoveryServiceFoundEvent) {
        // 发现只有名字，必须再解析才有 host/port；解析失败静默放弃。
        unawaited(
          discovery!.serviceResolver
              .resolveService(service)
              .catchError((Object _) {}),
        );
      } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
        final host = service.host;
        if (host == null || host.isEmpty) return;
        // 平台可能给带尾点的 mDNS 主机名（Mac.local.），去掉再进 Uri。
        final normalized = host.endsWith('.')
            ? host.substring(0, host.length - 1)
            : host;
        controller.add(
          Uri(scheme: 'http', host: normalized, port: service.port),
        );
      }
    });
    await discovery.start();
    await Future<void>.delayed(_window);
  } catch (_) {
    // 平台不可用（Linux 无 Avahi、权限拒绝等）：直接收流，回落扫段。
  } finally {
    await subscription?.cancel();
    try {
      await discovery?.stop();
    } catch (_) {
      // stop 失败不影响回落。
    }
    await controller.close();
  }
}
