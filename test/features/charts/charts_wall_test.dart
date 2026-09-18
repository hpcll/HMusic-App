import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/features/charts/data/api_charts_repository.dart';
import 'package:hmusic/features/charts/data/charts_repository.dart';
import 'package:hmusic/features/charts/models/chart.dart';
import 'package:hmusic/features/charts/view_models/charts_view_model.dart';
import 'package:hmusic/features/charts/widgets/chart_card.dart';
import 'package:hmusic/features/charts/widgets/charts_source_filter.dart';
import 'package:hmusic/features/charts/widgets/charts_wall.dart';

class _FakeChartsRepository implements ChartsRepository {
  const _FakeChartsRepository({this.spotify = false});
  final bool spotify;

  @override
  Future<List<Chart>> getCharts() async => <Chart>[
    if (spotify) ...const <Chart>[
      Chart(
        id: 'spotify-top-short',
        name: '最近常听',
        kind: 'spotify-personal',
        description: 'Spotify 最近 4 周常听曲目',
      ),
      Chart(
        id: 'spotify-top-medium',
        name: '半年常听',
        kind: 'spotify-personal',
        description: 'Spotify 最近 6 个月常听曲目',
      ),
      Chart(
        id: 'spotify-top-long',
        name: '长期常听',
        kind: 'spotify-personal',
        description: 'Spotify 较长时间的常听曲目',
      ),
      Chart(
        id: 'spotify-global-top',
        name: 'Global Top 50',
        kind: 'spotify-public',
      ),
    ],
    const Chart(id: 'family-hot', name: '家庭热播', kind: 'family'),
    const Chart(id: 'netease-hot', name: '热歌榜', kind: 'netease'),
    const Chart(id: 'netease-new', name: '新歌榜', kind: 'netease'),
    const Chart(id: 'qq-hot', name: '巅峰热歌榜', kind: 'qq'),
    const Chart(id: 'apple-cn', name: '热门歌曲 · 中国', kind: 'apple'),
  ];

  @override
  Future<ChartDetail> getChart(String id) async => ChartDetail(
    id: id,
    name: id,
    kind: id.startsWith('spotify-top') ? 'spotify-personal' : 'family',
    entries: const <ChartEntry>[
      ChartEntry(rank: 1, title: '晴天', artist: '周杰伦'),
      ChartEntry(rank: 2, title: '稻香', artist: '周杰伦'),
      ChartEntry(rank: 3, title: '七里香', artist: '周杰伦'),
    ],
  );

  @override
  Future<HMusicPlaybackState> playAll(String id, {int? startIndex}) async =>
      throw UnimplementedError();
}

class _LoadOnce extends ConsumerStatefulWidget {
  const _LoadOnce();
  @override
  ConsumerState<_LoadOnce> createState() => _LoadOnceState();
}

class _LoadOnceState extends ConsumerState<_LoadOnce> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref.read(chartsViewModelProvider.notifier).load(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const ChartsWall();
}

Future<void> _pump(
  WidgetTester tester, {
  bool spotify = false,
  double scale = 1,
  bool dark = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        chartsRepositoryProvider.overrideWithValue(
          _FakeChartsRepository(spotify: spotify),
        ),
      ],
      child: MaterialApp(
        theme: dark ? HMusicTheme.dark() : HMusicTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const RepaintBoundary(
          key: ValueKey('charts-review-surface'),
          child: Scaffold(body: _LoadOnce()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  _registerVisualCaptures();
  testWidgets('手机默认精选去重，保留搜索入口，榜单页不出现 Spotify 设置', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);
    expect(find.text('找歌'), findsOneWidget);
    expect(find.text('发现榜单'), findsOneWidget);
    expect(find.text('搜索歌曲或歌手'), findsOneWidget);
    expect(find.text('家庭热播'), findsOneWidget);
    expect(find.text('热歌榜'), findsOneWidget);
    expect(find.text('新歌榜'), findsNothing);
    expect(find.text('Spotify 设置'), findsNothing);
    expect(find.text('查看全部'), findsNothing);
  });

  testWidgets('选择平台后展示完整目录，卡片不再重复陈列', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);
    final netease = find.descendant(
      of: find.byType(ChartsSourceFilter),
      matching: find.text('网易云音乐'),
    );
    await tester.tap(netease);
    await tester.pumpAndSettle();
    expect(find.text('新歌榜'), findsOneWidget);
    expect(find.text('热歌榜'), findsOneWidget);
    expect(find.text('家庭热播'), findsNothing);
    expect(find.byType(ChartCard), findsNWidgets(2));
  });

  testWidgets('宽屏三个 Spotify 常听榜直接显示曲目，无需先打开详情', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, spotify: true);
    expect(find.byTooltip('首页推荐管理'), findsOneWidget);
    for (final title in ['最近常听', '半年常听', '长期常听']) {
      final card = find.ancestor(
        of: find.text(title),
        matching: find.byType(ChartCard),
      );
      expect(
        find.descendant(of: card, matching: find.text('晴天')),
        findsOneWidget,
      );
    }
    final horizontal = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .where(
          (scrollable) =>
              scrollable.widget.axisDirection == AxisDirection.right,
        );
    for (final scrollable in horizontal) {
      expect(scrollable.position.maxScrollExtent, 0);
    }
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 768.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('榜单 ${width}px / ${scale}x / ${dark ? '深色' : '浅色'} 不溢出', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await _pump(tester, spotify: true, scale: scale, dark: dark);
          expect(tester.takeException(), isNull);
          final target = find.descendant(
            of: find.byType(ChartsSourceFilter),
            matching: find.text('Apple Music'),
          );
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(find.text('热门歌曲 · 中国'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

// 可选的本地视觉验收；正常测试不写文件，不改变字体或依赖宿主字体。
void _registerVisualCaptures() {
  const directory = String.fromEnvironment('HMUSIC_CHARTS_CAPTURE_DIR');
  if (directory.isEmpty) return;
  const spotify = bool.fromEnvironment(
    'HMUSIC_CHARTS_CAPTURE_SPOTIFY',
    defaultValue: true,
  );
  const source = String.fromEnvironment('HMUSIC_CHARTS_CAPTURE_SOURCE');
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final serif = FontLoader('NotoSerifSC')
      ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-SemiBold.ttf'));
    await serif.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final systemFont = File('/System/Library/Fonts/STHeiti Light.ttc');
    final bytes = systemFont.existsSync()
        ? ByteData.sublistView(await systemFont.readAsBytes())
        : await rootBundle.load('assets/fonts/NotoSerifSC-Medium.ttf');
    await (FontLoader('Roboto')..addFont(Future.value(bytes))).load();
    await (FontLoader('PingFang SC')..addFont(Future.value(bytes))).load();
  });
  for (final (name, size, scale, dark) in <(String, Size, double, bool)>[
    ('desktop-light', const Size(1280, 1050), 1, false),
    ('desktop-dark', const Size(1280, 1050), 1, true),
    ('mobile', const Size(390, 844), 1, false),
    ('mobile-large-text', const Size(390, 844), 2, false),
  ]) {
    testWidgets('榜单视觉 $name', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(tester, spotify: spotify, scale: scale, dark: dark);
      if (source.isNotEmpty) {
        final target = find.descendant(
          of: find.byType(ChartsSourceFilter),
          matching: find.text(source),
        );
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      final surface = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('charts-review-surface')),
      );
      await tester.runAsync(() async {
        final image = await surface.toImage();
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(directory).create(recursive: true);
          await File(
            '$directory/app-$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    });
  }
}
