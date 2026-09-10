import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/app/shell/home_back_fallback.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/app/views/music_library_page.dart';
import 'package:hmusic/features/library/data/api_library_repository.dart';
import 'package:hmusic/features/library/models/library_view_state.dart';
import 'package:hmusic/features/library/view_models/library_view_model.dart';
import 'package:hmusic/features/playlists/data/api_playlists_repository.dart';
import 'package:hmusic/features/playlists/models/playlist.dart';
import 'package:hmusic/features/playlists/view_models/playlists_view_model.dart';

import '../features/library/support/fake_library_repository.dart';
import '../features/player/support/fake_playlists_repository.dart';

// 主审集成用例：同时挂真实曲库返回和外壳返回，防止一次返回被两层共同消费。
Future<(GoRouter, ProviderContainer)> _pumpLibraryShell(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  const paths = <String>[
    '/now',
    '/search-tab',
    '/queue-tab',
    '/playlists',
    '/charts',
    '/stats',
    '/settings',
  ];
  final router = GoRouter(
    initialLocation: MusicLibraryPage.path,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeBackFallback(
          shell: shell,
          child: Scaffold(body: shell),
        ),
        branches: <StatefulShellBranch>[
          for (final path in paths)
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: path,
                  builder: (context, state) => path == MusicLibraryPage.path
                      ? const MusicLibraryPage()
                      : Center(child: Text(path)),
                ),
              ],
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(
          FakeLibraryRepository(total: 3),
        ),
        playlistsRepositoryProvider.overrideWithValue(
          FakePlaylistsRepository(
            favorites: const PlaylistDetail(id: 'fav', name: '测试歌单'),
          ),
        ),
      ],
      child: MaterialApp.router(
        theme: HMusicTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    router,
    ProviderScope.containerOf(tester.element(find.byType(MusicLibraryPage))),
  );
}

void main() {
  testWidgets('歌单详情系统返回先收回曲库，下次才回找歌', (tester) async {
    final (router, container) = await _pumpLibraryShell(tester);
    await container
        .read(playlistsViewModelProvider.notifier)
        .openPlaylist('fav');
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/playlists');
    expect(container.read(playlistsViewModelProvider).detail, isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/charts');
    expect(tester.takeException(), isNull);
  });

  testWidgets('统计回到 NAS 原分组，下一次返回只关闭该分组', (tester) async {
    final (router, container) = await _pumpLibraryShell(tester);
    await tester.tap(find.text('NAS 歌曲'));
    await tester.pumpAndSettle();
    final library = container.read(libraryViewModelProvider.notifier);
    await library.setSection(LibrarySection.artists);
    await library.openGroup('林俊杰');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('听歌统计'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/stats');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/playlists');
    expect(container.read(libraryViewModelProvider).activeGroup, '林俊杰');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/playlists');
    expect(container.read(libraryViewModelProvider).activeGroup, isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/charts');
    expect(tester.takeException(), isNull);
  });
}
