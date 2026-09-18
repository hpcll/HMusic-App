import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/features/charts/models/chart.dart';
import 'package:hmusic/features/charts/models/charts_view_state.dart';
import 'package:hmusic/features/charts/view_models/charts_view_model.dart';
import 'package:hmusic/features/charts/widgets/chart_card.dart';
import 'package:hmusic/features/charts/widgets/chart_detail_header.dart';

void main() {
  const chart = Chart(
    id: 'spotify-global-top',
    name: '全球 Top 50',
    kind: 'spotify-public',
  );
  const notice = '暂时无法更新 Spotify，正在显示 2026-09-18 保存的榜单。';

  testWidgets('cached Spotify detail displays the dated offline notice', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartDetailHeader(
            state: const ChartsViewState(
              detail: ChartDetail(
                id: 'spotify-global-top',
                name: '全球 Top 50',
                kind: 'spotify-public',
                entries: [ChartEntry(rank: 1, title: '保存的歌曲', artist: '歌手')],
                notice: notice,
              ),
            ),
            notifier: container.read(chartsViewModelProvider.notifier),
            chart: chart,
            hasEntries: true,
          ),
        ),
      ),
    );
    expect(find.text(notice), findsOneWidget);
    expect(find.text('播放全部'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unreachable Spotify card provides a working retry without overflow',
    (tester) async {
      var retries = 0;
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 640),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 320,
                    height: ChartCard.heightFor(TextScaler.linear(scale)),
                    child: ChartCard(
                      chart: chart,
                      preview: null,
                      pending: false,
                      errorMessage: '当前网络无法访问 Spotify，请检查网络或先听其他榜单',
                      onOpen: () {},
                      onPlayEntry: (_) {},
                      onRetry: () => retries++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('当前网络无法访问 Spotify'), findsOneWidget);
        await tester.tap(find.text('重试'));
        expect(tester.takeException(), isNull);
      }
      expect(retries, 2);
    },
  );
}
