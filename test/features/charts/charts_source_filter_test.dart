import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/features/charts/models/chart.dart';
import 'package:hmusic/features/charts/widgets/charts_source_filter.dart';

const _charts = <Chart>[
  Chart(id: 'spotify-global-top', name: '全球热榜', kind: 'spotify-public'),
  Chart(id: 'wy-hot', name: '热歌榜', kind: 'netease'),
  Chart(id: 'qq-hot', name: 'QQ 热榜', kind: 'qq'),
  Chart(id: 'apple-cn', name: '中国热门', kind: 'apple'),
  Chart(id: 'family', name: '家庭热播', kind: 'family'),
];

Future<ScrollController> _pump(
  WidgetTester tester, {
  double width = 360,
  double scale = 1,
  bool reduceMotion = false,
  ValueChanged<String>? onSelected,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final page = ScrollController();
  addTearDown(page.dispose);
  var selected = 'featured';
  await tester.pumpWidget(
    MaterialApp(
      theme: HMusicTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          controller: page,
          child: Column(
            children: [
              const SizedBox(height: 400),
              StatefulBuilder(
                builder: (context, setState) => ChartsSourceFilter(
                  charts: _charts,
                  selected: selected,
                  onSelected: (value) {
                    setState(() => selected = value);
                    onSelected?.call(value);
                  },
                ),
              ),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      ),
    ),
  );
  page.jumpTo(120);
  await tester.pumpAndSettle();
  return page;
}

ScrollPosition _horizontal(WidgetTester tester) => tester
    .stateList<ScrollableState>(
      find.descendant(
        of: find.byType(ChartsSourceFilter),
        matching: find.byType(Scrollable),
      ),
    )
    .single
    .position;

void main() {
  for (final reduceMotion in [false, true]) {
    testWidgets('点击右侧可见分类后露出下一项，页面纵向位置不变（减动效 $reduceMotion）', (tester) async {
      String? selection;
      final page = await _pump(
        tester,
        reduceMotion: reduceMotion,
        onSelected: (value) => selection = value,
      );
      final horizontal = _horizontal(tester);
      final beforePage = page.offset;
      final next = find.text('QQ音乐');
      expect(tester.getRect(next).right, greaterThan(360));

      await tester.tap(find.text('网易云音乐'));
      if (reduceMotion) {
        await tester.pump();
        expect(horizontal.isScrollingNotifier.value, isFalse);
      } else {
        await tester.pumpAndSettle();
      }

      expect(selection, 'netease');
      expect(horizontal.pixels, greaterThan(0));
      expect(tester.getRect(next).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(next).right, lessThanOrEqualTo(360));
      expect(page.offset, beforePage);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (width, scale) in [(390.0, 2.0), (1280.0, 1.0)]) {
    testWidgets('首尾分类停在边界，宽屏无需平移（${width}px / ${scale}x）', (tester) async {
      final page = await _pump(tester, width: width, scale: scale);
      final horizontal = _horizontal(tester);
      final beforePage = page.offset;
      horizontal.jumpTo(horizontal.maxScrollExtent);
      await tester.pump();
      await tester.tap(find.text('HMusic'));
      await tester.pumpAndSettle();
      expect(horizontal.pixels, closeTo(horizontal.maxScrollExtent, 0.01));
      expect(page.offset, beforePage);

      horizontal.jumpTo(horizontal.maxScrollExtent > 10 ? 10 : 0);
      await tester.pump();
      await tester.tap(find.text('精选'));
      await tester.pumpAndSettle();
      expect(horizontal.pixels, 0);
      expect(page.offset, beforePage);
      if (width == 1280) expect(horizontal.maxScrollExtent, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
