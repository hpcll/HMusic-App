import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/features/connection/data/lan_server_scanner.dart';
import 'package:hmusic/features/connection/widgets/discovered_server_list.dart';

// 用户反馈：「中间那块发现服务器的 UI，不管啥状态占的位置固定，不要一会大一会
// 小」。扫描中 / 一无所获 / 有结果三种状态各自决定高度时，下面的手输区会跟着
// 状态上下窜。这里把三态的实际高度对起来机械守一层。
Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: child,
      ),
    ),
  ),
);

DiscoveredServerList _list({
  required bool discovering,
  required List<DiscoveredServer> servers,
}) => DiscoveredServerList(
  discovering: discovering,
  servers: servers,
  enabled: true,
  onConnect: (_) {},
  onRescan: () {},
);

DiscoveredServer _server(String host) => DiscoveredServer(
  base: Uri.parse('http://$host:6650'),
  name: 'HMusic Server',
  version: '0.1.0',
);

void main() {
  Future<double> heightOf(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(_host(child));
    await tester.pump();
    return tester.getSize(find.byType(DiscoveredServerList)).height;
  }

  testWidgets('扫描中 / 空态 / 有结果：发现区高度完全一致', (tester) async {
    final double scanning = await heightOf(
      tester,
      _list(discovering: true, servers: const <DiscoveredServer>[]),
    );
    final double empty = await heightOf(
      tester,
      _list(discovering: false, servers: const <DiscoveredServer>[]),
    );
    final double oneResult = await heightOf(
      tester,
      _list(
        discovering: false,
        servers: <DiscoveredServer>[_server('10.0.0.2')],
      ),
    );
    final double manyResults = await heightOf(
      tester,
      _list(
        discovering: false,
        servers: <DiscoveredServer>[
          _server('10.0.0.2'),
          _server('10.0.0.3'),
          _server('10.0.0.4'),
          _server('10.0.0.5'),
        ],
      ),
    );

    expect(scanning, DiscoveredServerList.kDiscoveryHeight);
    expect(empty, scanning);
    expect(oneResult, scanning);
    // 结果多到装不下也不长个儿：超出部分在框内滚。
    expect(manyResults, scanning);
  });

  // 定高是靠外层 SizedBox 撑的，内容溢出会在真机上画出黄条纹——三态都要能装下。
  testWidgets('三态都不溢出定高框', (tester) async {
    for (final Widget child in <Widget>[
      _list(discovering: true, servers: const <DiscoveredServer>[]),
      _list(discovering: false, servers: const <DiscoveredServer>[]),
      _list(
        discovering: false,
        servers: <DiscoveredServer>[_server('10.0.0.2')],
      ),
    ]) {
      await tester.pumpWidget(_host(child));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
