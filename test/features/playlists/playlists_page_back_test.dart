import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/features/playlists/data/api_playlists_repository.dart';
import 'package:hmusic/features/playlists/models/playlist.dart';
import 'package:hmusic/features/playlists/view_models/playlists_view_model.dart';
import 'package:hmusic/features/playlists/views/playlists_page.dart';

import '../player/support/fake_playlists_repository.dart';

void main() {
  testWidgets('歌单详情：系统返回收回列表；列表一级不再拦截', (tester) async {
    final repository = FakePlaylistsRepository(
      favorites: const PlaylistDetail(id: 'fav', name: '测试歌单'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playlistsRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: Scaffold(body: PlaylistsPage())),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlaylistsPage)),
      listen: false,
    );
    final notifier = container.read(playlistsViewModelProvider.notifier);
    await notifier.openPlaylist('fav');
    await tester.pumpAndSettle();
    expect(container.read(playlistsViewModelProvider).isList, isFalse);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(container.read(playlistsViewModelProvider).isList, isTrue);
  });
}
