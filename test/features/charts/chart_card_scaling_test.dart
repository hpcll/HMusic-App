import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/features/charts/models/chart.dart';
import 'package:hmusic/features/charts/widgets/charts_section_row.dart';

// 卡片按字号计算包络，在可纵向滚动的页面中保留系统字号；三类预览都不得溢出。
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
          body: SingleChildScrollView(
            child: ChartsSectionRow(
              label: '网易云音乐',
              charts: const <Chart>[_chart],
              previews: previews,
              onOpen: (_) {},
              onPlayEntry: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('预览歌手位于歌名下方，点预览只播放而不打开整榜', (tester) async {
    var opens = 0;
    var plays = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChartsSectionRow(
              label: '网易云音乐',
              charts: const <Chart>[_chart],
              previews: const <String, List<ChartEntry>?>{'netease-hot': _top3},
              onOpen: (_) => opens++,
              onPlayEntry: (_) => plays++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text(_top3.first.artist)).dy,
      greaterThan(tester.getTopLeft(find.text(_top3.first.title)).dy),
    );
    await tester.tap(find.text(_top3.first.title));
    expect(plays, 1);
    expect(opens, 0);
  });

  // 覆盖原 1.2 倍钳制边界，以及 Android/iOS 常见的大字号档位。
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

  testWidgets('卡内文字保留系统字号，靠布局增高容纳', (tester) async {
    await _pumpRow(
      tester,
      textScale: 3.1,
      previews: <String, List<ChartEntry>?>{_chart.id: _top3},
    );

    // 不再牺牲无障碍字号来隐藏溢出。
    final context = tester.element(find.text('稻香'));
    expect(MediaQuery.textScalerOf(context).scale(10), closeTo(31, 0.001));
  });
}
