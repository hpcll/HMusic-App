import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/features/charts/data/api_charts_repository.dart';
import 'package:hmusic/features/charts/data/charts_repository.dart';
import 'package:hmusic/features/charts/models/chart.dart';
import 'package:hmusic/features/charts/view_models/charts_view_model.dart';
import 'package:hmusic/features/charts/views/charts_page.dart';
import 'package:hmusic/features/settings/data/api_downloads_repository.dart';
import 'package:hmusic/features/settings/data/downloads_repository.dart';
import 'package:hmusic/features/settings/models/download_record.dart';
import 'package:hmusic/shared/widgets/hmusic_icon_button.dart';
import 'package:hmusic/shared/widgets/hmusic_track_row.dart';

const HMusicTrack _archived = HMusicTrack(
  id: 'wy-1',
  source: 'wy',
  sourceTrackId: '1',
  title: '已入库的歌',
  artist: '甲',
);

const HMusicTrack _fresh = HMusicTrack(
  id: 'wy-2',
  source: 'wy',
  sourceTrackId: '2',
  title: '还没入库的歌',
  artist: '乙',
);

class _FakeChartsRepository implements ChartsRepository {
  const _FakeChartsRepository();

  @override
  Future<List<Chart>> getCharts() async => const <Chart>[
    Chart(id: 'hot', name: '云村飙升榜', kind: 'netease'),
  ];

  @override
  Future<ChartDetail> getChart(String id) async => const ChartDetail(
    id: 'hot',
    name: '云村飙升榜',
    kind: 'netease',
    entries: <ChartEntry>[
      ChartEntry(rank: 1, title: '已入库的歌', artist: '甲', track: _archived),
      ChartEntry(rank: 2, title: '还没入库的歌', artist: '乙', track: _fresh),
    ],
  );

  @override
  Future<HMusicPlaybackState> playAll(String id, {int? startIndex}) async =>
      throw UnimplementedError();
}

class _FakeDownloadsRepository implements DownloadsRepository {
  final List<HMusicTrack> started = <HMusicTrack>[];

  // 服务端对刚发起的那首会先报 pending/downloading，落地后才变 done：
  // 用它复刻「下完了列表页该自己变对勾」这条时间线。
  DownloadStatus startedStatus = DownloadStatus.downloading;

  @override
  Future<List<DownloadRecord>> list() async => <DownloadRecord>[
    const DownloadRecord(
      id: 'd1',
      title: '已入库的歌',
      status: DownloadStatus.done,
      track: _archived,
    ),
    for (final track in started)
      DownloadRecord(
        id: 'd-${track.sourceTrackId}',
        title: track.title,
        status: startedStatus,
        track: track,
      ),
  ];

  @override
  Future<void> start(HMusicTrack track, {String? quality}) async {
    started.add(track);
  }

  @override
  Future<void> remove(String id) async {}

  @override
  Future<void> retry(HMusicTrack track) async => start(track);
}

Future<ProviderContainer> _openChart(
  WidgetTester tester,
  _FakeDownloadsRepository downloads,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chartsRepositoryProvider.overrideWithValue(
          const _FakeChartsRepository(),
        ),
        downloadsRepositoryProvider.overrideWithValue(downloads),
      ],
      child: const MaterialApp(home: Scaffold(body: ChartsPage())),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ChartsPage)),
    listen: false,
  );
  await container
      .read(chartsViewModelProvider.notifier)
      .openChart(const Chart(id: 'hot', name: '云村飙升榜', kind: 'netease'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  // 用户反馈：榜单里必须点那个小播放钮才能放，希望点整行就播、把钮去掉。
  testWidgets('榜单行：整行即播放键，行上不再有播放钮', (tester) async {
    await _openChart(tester, _FakeDownloadsRepository());

    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    for (final row in tester.widgetList<HMusicTrackRow>(
      find.byType(HMusicTrackRow),
    )) {
      expect(row.onTap, isNotNull);
    }
  });

  // 用户反馈：榜单的歌没入库。进详情时拉一次 /downloads 建索引：已入库的行在
  // 原来下载钮那一格显示灰对勾（不另在标题旁挂角标），没入库的给下载钮。
  testWidgets('榜单行：已入库在行尾显示对勾，没入库给下载钮', (tester) async {
    await _openChart(tester, _FakeDownloadsRepository());

    expect(find.byIcon(Icons.download_done_rounded), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    // 对勾是「既成状态」，不可点。
    final done = tester.widget<HMusicIconButton>(
      find
          .ancestor(
            of: find.byIcon(Icons.download_done_rounded),
            matching: find.byType(HMusicIconButton),
          )
          .first,
    );
    expect(done.onPressed, isNull);
  });

  testWidgets('点下载钮：发起入库并把该行标成排队中', (tester) async {
    final downloads = _FakeDownloadsRepository();
    final container = await _openChart(tester, downloads);

    await tester.tap(find.byIcon(Icons.download_rounded));
    // 不用 pumpAndSettle：排队中的行在转菊花，永远settle不了。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(downloads.started.single.sourceTrackId, '2');
    expect(
      container.read(chartsViewModelProvider).downloads['wy:2'],
      DownloadStatus.pending,
    );
    // 排队中的行转菊花，下载钮收起（同一位置不再可点）。
    expect(find.byIcon(Icons.download_rounded), findsNothing);

    // 成功提示走全局 toast（3.2s 自动收）：放它走完，否则拆树时还有待触发的
    // 定时器，测试框架会报错。
    await tester.pump(const Duration(seconds: 4));
  });

  // 用户反馈：下完了停在榜单页也不变成完成状态，得退出重进才看得到。
  // 有活跃条目就每 3s 拉一次 /downloads，落地即停表。
  testWidgets('停在榜单页：下载完成后该行自己变成对勾，轮询随之停表', (tester) async {
    final downloads = _FakeDownloadsRepository();
    await _openChart(tester, downloads);

    await tester.tap(find.byIcon(Icons.download_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // 下载中：那一格是菊花，没有可点的下载钮。
    expect(find.byIcon(Icons.download_rounded), findsNothing);

    // 服务端那边落地了：下一次轮询就该把这一行翻成对勾。
    downloads.startedStatus = DownloadStatus.done;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.byIcon(Icons.download_done_rounded), findsNWidgets(2));

    // 没有活跃条目了 → 表停掉（否则拆树时会有待触发的定时器，测试框架报错）。
    await tester.pump(const Duration(seconds: 4));
  });
}
