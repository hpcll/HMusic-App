import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/app/views/music_library_page.dart';
import 'package:hmusic/core/queue/api_queue_repository.dart';
import 'package:hmusic/features/library/data/api_library_repository.dart';
import 'package:hmusic/features/library/models/library_view_state.dart';
import 'package:hmusic/features/library/view_models/library_view_model.dart';
import 'package:hmusic/features/library/widgets/library_view.dart';
import 'package:hmusic/features/player/widgets/desktop_playback_metrics.dart';
import 'package:hmusic/features/playlists/data/api_playlists_repository.dart';
import 'package:hmusic/shared/layout/shell_metrics.dart';
import 'package:hmusic/shared/widgets/hmusic_adaptive_track_row.dart';

import '../features/library/support/fake_library_repository.dart';
import '../features/player/support/fake_playlists_repository.dart';
import '../features/queue/support/fake_queue_repository.dart';

const _chromeKey = ValueKey<String>('playback-chrome-occlusion');

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required Size viewport,
  required double scale,
  required FakeLibraryRepository library,
  required FakeQueueRepository queue,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final scaler = TextScaler.linear(scale);
  final sideWidth = shellNavigationWidth(viewport.width);
  final chromeHeight = usesBottomNavigation(viewport.width)
      ? mobileMiniPlayerHeight(scaler) +
            mobileDockHeight(scaler) +
            kChromeGap +
            chromeBottomOffset(24, platform: TargetPlatform.android) +
            kChromeContentClearance
      : 24 +
            desktopPlaybackBarHeight(
              contentWidth: viewport.width - sideWidth,
              textScaler: scaler,
            );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(library),
        playlistsRepositoryProvider.overrideWithValue(
          FakePlaylistsRepository(),
        ),
        queueRepositoryProvider.overrideWithValue(queue),
      ],
      child: MaterialApp(
        theme: HMusicTheme.light(),
        home: Scaffold(
          body: MediaQuery(
            // 与外壳一致，body 延伸到 chrome 背后，由内容负责底部滚动让位。
            data: MediaQueryData(
              size: viewport,
              textScaler: scaler,
              padding: EdgeInsets.only(top: 28, bottom: chromeHeight),
            ),
            child: Padding(
              padding: EdgeInsets.only(left: sideWidth),
              child: Stack(
                children: <Widget>[
                  const Positioned.fill(child: MusicLibraryPage()),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: chromeHeight,
                    child: const ColoredBox(
                      key: _chromeKey,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('NAS 歌曲'));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(MusicLibraryPage)),
  );
}

void _expectAboveChrome(WidgetTester tester, Finder target) {
  final bounds = tester.getRect(target);
  final browser = tester.getRect(find.byType(LibraryView));
  final chrome = tester.getRect(find.byKey(_chromeKey));
  expect(bounds.top, greaterThanOrEqualTo(browser.top - 0.5));
  expect(
    bounds.bottom,
    lessThanOrEqualTo(chrome.top),
    reason: '操作必须完整滚到常驻播放区上方，而不是仍被遮住',
  );
}

void main() {
  for (final sample in <({Size viewport, double scale})>[
    (viewport: const Size(360, 640), scale: 2),
    (viewport: const Size(844, 390), scale: 1),
  ]) {
    testWidgets('${sample.viewport} ${sample.scale}倍字：搜索和曲目能滚到播放区上方并操作', (
      tester,
    ) async {
      final library = FakeLibraryRepository(total: 3);
      final queue = FakeQueueRepository(queue: buildQueue());
      final container = await _pump(
        tester,
        viewport: sample.viewport,
        scale: sample.scale,
        library: library,
        queue: queue,
      );
      final search = find.byType(TextField);
      await tester.ensureVisible(search);
      await tester.pumpAndSettle();
      _expectAboveChrome(tester, search);
      await tester.enterText(search, '本地曲目');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(container.read(libraryViewModelProvider).query, '本地曲目');

      final row = find.byWidgetPredicate(
        (widget) =>
            widget is HMusicAdaptiveTrackRow && widget.track.id == 'local:0',
      );
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      _expectAboveChrome(tester, row);
      final enqueue = find.descendant(
        of: row,
        matching: find.byTooltip('加入队列'),
      );
      await tester.tap(enqueue);
      await tester.pumpAndSettle();
      expect(queue.calls, contains('add:local:0'));

      final browser = tester.getRect(find.byType(LibraryView));
      final chrome = tester.getRect(find.byKey(_chromeKey));
      await tester.dragFrom(
        Offset(browser.center.dx, chrome.top - 20),
        const Offset(0, 500),
      );
      await tester.pumpAndSettle();
      final artists = find.widgetWithText(ChoiceChip, '歌手');
      await tester.ensureVisible(artists);
      await tester.pumpAndSettle();
      _expectAboveChrome(tester, artists);
      await tester.tap(artists);
      await tester.pumpAndSettle();
      expect(
        container.read(libraryViewModelProvider).section,
        LibrarySection.artists,
      );
      final group = find.widgetWithText(ListTile, '林俊杰');
      await tester.ensureVisible(group);
      await tester.pumpAndSettle();
      _expectAboveChrome(tester, group);
      await tester.tap(group);
      await tester.pumpAndSettle();
      expect(container.read(libraryViewModelProvider).activeGroup, '林俊杰');
      final back = find.ancestor(
        of: find.text('林俊杰'),
        matching: find.byWidgetPredicate((widget) => widget is TextButton),
      );
      await tester.ensureVisible(back);
      await tester.pumpAndSettle();
      _expectAboveChrome(tester, back);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(container.read(libraryViewModelProvider).showsGroups, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('工具与曲目共同滚动，分页仍懒加载且末项可滚到播放区上方', (tester) async {
    final library = FakeLibraryRepository(total: 120);
    final queue = FakeQueueRepository(queue: buildQueue());
    final container = await _pump(
      tester,
      viewport: const Size(360, 640),
      scale: 2,
      library: library,
      queue: queue,
    );
    expect(container.read(libraryViewModelProvider).items, hasLength(50));
    expect(find.byType(HMusicAdaptiveTrackRow).evaluate().length, lessThan(50));
    final last = find.byWidgetPredicate(
      (widget) =>
          widget is HMusicAdaptiveTrackRow && widget.track.id == 'local:119',
    );
    final browser = tester.getRect(find.byType(LibraryView));
    final chrome = tester.getRect(find.byKey(_chromeKey));
    // 全视口的中心可能在播放栏背后，从用户实际可触及的内容区起拖。
    for (var count = 0; last.evaluate().isEmpty && count < 60; count++) {
      await tester.dragFrom(
        Offset(browser.center.dx, chrome.top - 20),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
    }
    expect(last, findsOneWidget);
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    _expectAboveChrome(tester, last);
    expect(library.calls, contains('list::null:null:null:50:50'));
    expect(library.calls, contains('list::null:null:null:50:100'));
    expect(
      find.byType(HMusicAdaptiveTrackRow).evaluate().length,
      lessThan(120),
    );
    await tester.tap(
      find.descendant(of: last, matching: find.byTooltip('加入队列')),
    );
    await tester.pumpAndSettle();
    expect(queue.calls, contains('add:local:119'));
  });
}
