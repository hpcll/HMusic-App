import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/server_info.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/infrastructure_providers.dart';
import 'mdns_discovery.dart';

// 局域网自动发现，两级候选源 + 统一确认管线：
//   1. mDNS 订阅（主路径）：Server 自广播 _hmusic._tcp，秒级、任意端口；
//   2. HTTP 扫段（兜底）：mDNS 静默 2s 才启动，按 /24 并发探默认端口 8090
//      ——路由器禁 mDNS、Linux 无 Avahi 等场景仍可用。
// 候选一律过 /system/info 身份确认（name + apiVersion）再算数。
const int _serverPort = 8090;
const int _probeConcurrency = 32;

class DiscoveredServer {
  const DiscoveredServer({
    required this.base,
    required this.name,
    required this.version,
  });

  final Uri base;
  final String name;
  final String version;
}

// 探测走独立短超时 ApiClient：共享 Dio 的 5s connectTimeout 会把整段扫描拖到
// 40s+，600ms 对局域网握手绰绰有余；HTTP 仍统一经 ApiClient，不裸建请求。
final Provider<LanServerScanner> lanServerScannerProvider =
    Provider<LanServerScanner>((ref) {
      final probeClient = ApiClient(
        dio: Dio(
          BaseOptions(
            connectTimeout: const Duration(milliseconds: 600),
            receiveTimeout: const Duration(seconds: 2),
            responseType: ResponseType.json,
          ),
        ),
        serverConfigStore: ref.watch(serverConfigStoreProvider),
        tokenStore: ref.watch(tokenStoreProvider),
      );
      return LanServerScanner(
        probe: (base) => probeClient.getMap(
          '/system/info',
          serverBase: base,
          authenticated: false,
        ),
        localAddresses: () async {
          final interfaces = await NetworkInterface.list(
            type: InternetAddressType.IPv4,
            includeLoopback: false,
          );
          return <String>[
            for (final interface in interfaces)
              for (final address in interface.addresses) address.address,
          ];
        },
        mdnsCandidates: ref.watch(mdnsCandidatesProvider),
      );
    });

class LanServerScanner {
  LanServerScanner({
    required this.probe,
    required this.localAddresses,
    required this.mdnsCandidates,
    this.sweepDelay = const Duration(seconds: 2),
  });

  // 三个依赖都以函数注入，单测不碰真实网卡、网络与 mDNS。
  final Future<Map<String, Object?>> Function(Uri base) probe;
  final Future<List<String>> Function() localAddresses;
  final Stream<Uri> Function() mdnsCandidates;

  // mDNS 静默多久后启动扫段兜底；单测注 Duration.zero 免等。
  final Duration sweepDelay;

  // 逐台 yield：先确认先显示，不等全部候选跑完。
  Stream<DiscoveredServer> scan() {
    final controller = StreamController<DiscoveredServer>();
    final seen = <String>{};
    var confirmedAny = false;

    Future<void> confirm(Uri base) async {
      if (!seen.add(base.toString())) return;
      final server = await _probeBase(base);
      if (server == null) return;
      confirmedAny = true;
      controller.add(server);
    }

    Future<void> run() async {
      final mdnsDone = _pumpMdns(confirm);
      // 零延迟（测试注入）不建 Timer，widget 测试单次 pump 即可收干净。
      if (sweepDelay > Duration.zero) {
        await Future<void>.delayed(sweepDelay);
      }
      // mDNS 已有确认结果就不再射扫段包；一台都没有才兜底全网段。
      final sweepDone = confirmedAny ? Future<void>.value() : _sweep(confirm);
      await Future.wait(<Future<void>>[mdnsDone, sweepDone]);
      await controller.close();
    }

    unawaited(run());
    return controller.stream;
  }

  Future<void> _pumpMdns(Future<void> Function(Uri base) confirm) async {
    final pending = <Future<void>>[];
    try {
      await for (final base in mdnsCandidates()) {
        pending.add(confirm(base));
      }
    } catch (_) {
      // 候选源失败视同无结果，由扫段兜底。
    }
    await Future.wait(pending);
  }

  Future<void> _sweep(Future<void> Function(Uri base) confirm) async {
    List<String> hosts;
    try {
      hosts = candidateHosts(await localAddresses());
    } catch (_) {
      return;
    }
    for (var start = 0; start < hosts.length; start += _probeConcurrency) {
      final batch = hosts.skip(start).take(_probeConcurrency);
      await Future.wait(
        batch.map(
          (host) => confirm(Uri(scheme: 'http', host: host, port: _serverPort)),
        ),
      );
    }
  }

  Future<DiscoveredServer?> _probeBase(Uri base) async {
    try {
      final info = ServerInfo.fromJson(await probe(base));
      if (info.name != 'HMusic Server' || info.apiVersion != 'v1') return null;
      return DiscoveredServer(
        base: base,
        name: info.name,
        version: info.version,
      );
    } catch (_) {
      // 探不通、答非所问都不是错误，只说明这台机器不是 HMusic Server。
      return null;
    }
  }
}

// 纯函数便于单测：本机各地址按 /24 展开 .1–.254（Dart 拿不到子网掩码，
// 家庭网按 /24），剔除链路本地网段，多网卡并集去重、保持网卡顺序。
// 本机自身 IP 也要探：桌面端 App 和 Server 常在同一台机器上（正是本项目
// 的开发形态），漏掉自己就永远扫不到同机 Server。
List<String> candidateHosts(List<String> ownAddresses) {
  final result = <String>[];
  final seen = <String>{};
  for (final address in ownAddresses) {
    if (address.startsWith('169.254.')) continue;
    final lastDot = address.lastIndexOf('.');
    if (lastDot <= 0) continue;
    final prefix = address.substring(0, lastDot);
    for (var host = 1; host <= 254; host += 1) {
      final candidate = '$prefix.$host';
      if (seen.add(candidate)) result.add(candidate);
    }
  }
  return result;
}
