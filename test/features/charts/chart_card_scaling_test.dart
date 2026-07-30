import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/features/charts/models/chart.dart';
import 'package:hmusic/features/charts/widgets/charts_section_row.dart';

// 榜单卡带是像素级等高包络（_cardHeight 162 / 预览区 78）：改动前在无障碍大字号下
// 会精确溢出成黄黑警告条。这里把各字号档跑一遍，断言零溢出——纯 pixel 断言难覆盖，
// 交给 widget 测守。
const Chart _chart = Chart(
  id: 'netease-hot',
  name: '云村飙升榜',
  kind: 'netease',
  description: '这是一段足够长的榜单描述文案，用来占满回退分支的三行包络，确认它同样不溢出。',
);

const List<ChartEntry> _top3 = <ChartEntry>[
  ChartEntry(rank: 1, title: '一首标题相当长的歌曲名称用来触发省略', artist: '某位名字也不短的歌手'),
  ChartEntry(rank: 2, title: '稻香', artist: '周杰伦'),
  ChartEntry(rank: 3, title: '七里香', artist: '周杰伦'),
];

Future<void> _pumpRow(
  WidgetTester tester, {
  required double textScale,
  required Map<String, List<ChartEntry>?> previews,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: ChartsSectionRow(
            label: '网易云音乐',
            charts: const <Chart>[_chart],
            previews: previews,
            onOpen: (_) {},
            onPlayEntry: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  // iOS「更大字体」最大档约 3.1、Android 约 2.0；跨过钳制阈值 1.2 各取样点。
  const List<double> scales = <double>[1.0, 1.2, 1.3, 2.0, 3.1];

  for (final scale in scales) {
    testWidgets('字号 ${scale}x：Top3 预览不溢出', (tester) async {
      await _pumpRow(
        tester,
        textScale: scale,
        previews: <String, List<ChartEntry>?>{_chart.id: _top3},
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('字号 ${scale}x：描述回退不溢出', (tester) async {
      await _pumpRow(
        tester,
        textScale: scale,
        previews: <String, List<ChartEntry>?>{_chart.id: null},
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('字号 ${scale}x：加载骨架不溢出', (tester) async {
      await _pumpRow(
        tester,
        textScale: scale,
        previews: const <String, List<ChartEntry>?>{},
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('字号钳到 1.2：卡带内文字不随系统字号无限放大', (tester) async {
    await _pumpRow(
      tester,
      textScale: 3.1,
      previews: <String, List<ChartEntry>?>{_chart.id: _top3},
    );

    // 卡内文本拿到的是钳后倍率，而非系统的 3.1。
    final context = tester.element(find.text('稻香'));
    expect(MediaQuery.textScalerOf(context).scale(10), closeTo(12, 0.001));
  });
}
