import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/features/player/widgets/player_favorite_button.dart';
import 'package:hmusic/features/playlists/data/api_playlists_repository.dart';
import 'package:hmusic/features/playlists/models/playlist.dart';

import 'support/fake_playlists_repository.dart';

const HMusicTrack _track = HMusicTrack(
  id: 'tx:1',
  source: 'tx',
  sourceTrackId: '1',
  title: '晴天',
  artist: '周杰伦',
);

Future<void> _pump(
  WidgetTester tester,
  FakePlaylistsRepository repository, {
  HMusicTrack? track = _track,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [playlistsRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: PlayerFavoriteButton(track: track)),
        ),
      ),
    ),
  );
  // 两拍：挂载 microtask 触发 load + 快照回填重建。
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('未收藏点击 → 建单加歌，图标转实心', (tester) async {
    final repository = FakePlaylistsRepository();
    await _pump(tester, repository);

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.pump();

    expect(repository.calls, contains('create:我喜欢的音乐'));
    expect(repository.calls, contains('add:fav:1'));
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('已收藏初始即实心，点击移除转空心', (tester) async {
    final repository = FakePlaylistsRepository(
      favorites: const PlaylistDetail(
        id: 'fav',
        name: '我喜欢的音乐',
        items: <PlaylistItem>[PlaylistItem(id: 'item-1', track: _track)],
      ),
    );
    await _pump(tester, repository);

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.pump();

    expect(repository.calls, contains('remove:fav:item-1'));
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
  });

  testWidgets('无曲目时按钮禁用', (tester) async {
    await _pump(tester, FakePlaylistsRepository(), track: null);

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
  });
}
