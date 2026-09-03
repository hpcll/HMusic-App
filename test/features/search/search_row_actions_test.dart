import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/features/search/data/api_search_repository.dart';
import 'package:hmusic/features/search/data/search_repository.dart';
import 'package:hmusic/features/search/models/search_result.dart';
import 'package:hmusic/features/search/views/search_page.dart';
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

class _FakeSearchRepository implements SearchRepository {
  const _FakeSearchRepository();

  @override
  Future<SearchResult> search(String query) async => const SearchResult(
    query: '晴天',
    page: 1,
    limit: 20,
    total: 2,
    tracks: <HMusicTrack>[_archived, _fresh],
  );
}

class _FakeDownloadsRepository implements DownloadsRepository {
  final List<HMusicTrack> started = <HMusicTrack>[];
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

Future<void> _search(
  WidgetTester tester,
  _FakeDownloadsRepository downloads,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        searchRepositoryProvider.overrideWithValue(
          const _FakeSearchRepository(),
        ),
        downloadsRepositoryProvider.overrideWithValue(downloads),
      ],
      child: const MaterialApp(home: SearchPage()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '晴天');
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

void main() {
  // 与榜单行同一套交互（用户要求两页一致）：整行即播放键，行上不留播放钮。
  testWidgets('搜索结果行：整行即播放键，行上不再有播放钮', (tester) async {
    await _search(tester, _FakeDownloadsRepository());

    expect(find.byType(HMusicTrackRow), findsNWidgets(2));
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    for (final row in tester.widgetList<HMusicTrackRow>(
      find.byType(HMusicTrackRow),
    )) {
      expect(row.onTap, isNotNull);
    }
  });

  // 入库位三态同宽：已入库是灰对勾（不可点），没入库是下载钮。
  testWidgets('搜索结果行：已入库显示对勾，没入库给下载钮', (tester) async {
    await _search(tester, _FakeDownloadsRepository());

    expect(find.byIcon(Icons.download_done_rounded), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
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
}
