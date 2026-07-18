import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/features/connection/data/lan_server_scanner.dart';

Map<String, Object?> _serverPayload() => <String, Object?>{
  'name': 'HMusic Server',
  'version': '0.1.0',
  'apiVersion': 'v1',
};

void main() {
  group('candidateHosts', () {
    test('/24 展开 .1–.254，本机自身也要探（同机 Server 场景）', () {
      final hosts = candidateHosts(<String>['192.168.31.11']);
      expect(hosts, hasLength(254));
      expect(hosts, contains('192.168.31.11'));
      expect(hosts.first, '192.168.31.1');
      expect(hosts.last, '192.168.31.254');
    });

    test('链路本地网段不参与扫描', () {
      expect(candidateHosts(<String>['169.254.10.2']), isEmpty);
    });

    test('多网卡取并集，同网段不重复展开', () {
      final hosts = candidateHosts(<String>[
        '192.168.31.11',
        '192.168.31.12',
        '10.0.0.5',
      ]);
      expect(hosts.where((h) => h.startsWith('192.168.31.')), hasLength(254));
      expect(hosts.where((h) => h.startsWith('10.0.0.')), hasLength(254));
    });
  });

  group('scan', () {
    test('mDNS 候选确认即出，且不再触发扫段兜底', () async {
      var sweepTouched = false;
      final probed = <String>[];
      final scanner = LanServerScanner(
        sweepDelay: const Duration(milliseconds: 100),
        mdnsCandidates: () =>
            Stream<Uri>.fromIterable(<Uri>[Uri.parse('http://10.0.0.7:9000')]),
        localAddresses: () async {
          sweepTouched = true;
          return <String>['192.168.31.11'];
        },
        probe: (base) async {
          probed.add(base.toString());
          if (base.toString() == 'http://10.0.0.7:9000') {
            return _serverPayload();
          }
          throw Exception('offline');
        },
      );

      final found = await scanner.scan().toList();

      expect(found, hasLength(1));
      // mDNS 广播携带自定义端口也能被发现——不再受默认端口 8090 限制。
      expect(found.single.base.toString(), 'http://10.0.0.7:9000');
      expect(sweepTouched, isFalse);
      expect(probed, <String>['http://10.0.0.7:9000']);
    });

    test('mDNS 空流：扫段兜底照常，身份匹配才算发现', () async {
      final scanner = LanServerScanner(
        sweepDelay: Duration.zero,
        mdnsCandidates: () => const Stream<Uri>.empty(),
        localAddresses: () async => <String>['192.168.31.11'],
        probe: (base) async {
          switch (base.host) {
            case '192.168.31.1':
              return _serverPayload();
            case '192.168.31.2':
              // 端口开着但不是 HMusic（身份不符）。
              return <String, Object?>{
                'name': 'Some NAS',
                'version': '9',
                'apiVersion': 'v1',
              };
            case '192.168.31.3':
              // 返回缺字段的畸形载荷（fromJson 抛错也要被吞掉）。
              return <String, Object?>{'hello': 'world'};
            default:
              throw Exception('offline');
          }
        },
      );

      final found = await scanner.scan().toList();

      expect(found, hasLength(1));
      expect(found.single.base.toString(), 'http://192.168.31.1:8090');
      expect(found.single.name, 'HMusic Server');
      expect(found.single.version, '0.1.0');
    });

    test('mDNS 候选身份不符：不入结果，扫段兜底仍启动并去重', () async {
      final scanner = LanServerScanner(
        sweepDelay: Duration.zero,
        // 假冒者 + 与扫段重叠的真身：验证身份过滤与按 base 去重。
        mdnsCandidates: () => Stream<Uri>.fromIterable(<Uri>[
          Uri.parse('http://10.0.0.9:8090'),
          Uri.parse('http://192.168.31.1:8090'),
        ]),
        localAddresses: () async => <String>['192.168.31.11'],
        probe: (base) async {
          if (base.host == '192.168.31.1') return _serverPayload();
          if (base.host == '10.0.0.9') {
            return <String, Object?>{
              'name': 'Fake Speaker',
              'version': '1',
              'apiVersion': 'v1',
            };
          }
          throw Exception('offline');
        },
      );

      final found = await scanner.scan().toList();

      expect(found, hasLength(1));
      expect(found.single.base.toString(), 'http://192.168.31.1:8090');
    });
  });
}
