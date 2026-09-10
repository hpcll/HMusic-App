import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

class _WritablePlaylistsRepository extends FakePlaylistsRepository {
  _WritablePlaylistsRepository()
    : super(
        favorites: const PlaylistDetail(id: 'fav', name: '测试歌单'),
      );

  @override
  Future<void> deletePlaylist(String id) async {
    calls.add('delete:$id');
    favorites = null;
  }

  @override
  Future<PlaylistImportResult> importPlaylist(String url) async {
    calls.add('import:$url');
    favorites = const PlaylistDetail(id: 'imported', name: '导入的歌单');
    return const PlaylistImportResult(
      name: '导入的歌单',
      imported: 2,
      skipDuplicate: 1,
    );
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeLibraryRepository library,
  required FakePlaylistsRepository playlists,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(library),
        playlistsRepositoryProvider.overrideWithValue(playlists),
      ],
      child: MaterialApp(
        theme: HMusicTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(400, 900),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const Scaffold(body: MusicLibraryPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(MusicLibraryPage)),
  );
}

void main() {
  testWidgets('根歌单仍能创建和导入，导入结果在页内展示', (tester) async {
    final playlists = _WritablePlaylistsRepository();
    await _pump(
      tester,
      library: FakeLibraryRepository(total: 0),
      playlists: playlists,
    );
    await tester.tap(find.text('创建歌单'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '晚间精选');
    await tester.pump();
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(playlists.calls, contains('create:晚间精选'));
    expect(find.text('晚间精选'), findsOneWidget);

    await tester.tap(find.text('导入'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://music.example/playlist',
    );
    await tester.pump();
    await tester.tap(find.text('开始导入'));
    await tester.pumpAndSettle();
    expect(playlists.calls, contains('import:https://music.example/playlist'));
    expect(find.textContaining('已导入 2 首'), findsOneWidget);
    expect(find.text('导入的歌单'), findsOneWidget);
  });

  testWidgets('根分段直接进入 NAS，切换与调整宽度保留查询和分组', (tester) async {
    final library = FakeLibraryRepository(total: 3);
    final playlists = _WritablePlaylistsRepository();
    final container = await _pump(
      tester,
      library: library,
      playlists: playlists,
    );
    expect(library.calls, isEmpty);
    expect(find.byTooltip('听歌统计'), findsOneWidget);

    await tester.tap(find.text('NAS 歌曲'));
    await tester.pumpAndSettle();
    expect(
      library.calls.where((call) => call.startsWith('list:')),
      hasLength(1),
    );
    expect(find.text('上传'), findsOneWidget);
    expect(find.text('扫描'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '晴天');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    final notifier = container.read(libraryViewModelProvider.notifier);
    await notifier.setSection(LibrarySection.artists);
    await notifier.openGroup('林俊杰');
    await tester.pumpAndSettle();

    await tester.tap(find.text('歌单'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1180, 900);
    await tester.pump();
    await tester.tap(find.text('NAS 歌曲'));
    await tester.pumpAndSettle();
    expect(container.read(libraryViewModelProvider).activeGroup, '林俊杰');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '晴天',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('返回只处理当前根分段，隐藏 NAS 分组和歌单详情均不拦截', (tester) async {
    final container = await _pump(
      tester,
      library: FakeLibraryRepository(total: 3),
      playlists: _WritablePlaylistsRepository(),
    );
    await tester.tap(find.text('NAS 歌曲'));
    await tester.pumpAndSettle();
    final nas = container.read(libraryViewModelProvider.notifier);
    await nas.setSection(LibrarySection.artists);
    await nas.openGroup('林俊杰');
    await tester.pumpAndSettle();
    await tester.tap(find.text('歌单'));
    await tester.pumpAndSettle();

    // NAS 分组保持打开但已隐藏，歌单根页的返回交还外壳。
    expect(await tester.binding.handlePopRoute(), isFalse);
    await tester.pumpAndSettle();
    expect(container.read(libraryViewModelProvider).activeGroup, '林俊杰');

    await tester.tap(find.text('NAS 歌曲'));
    await tester.pumpAndSettle();
    // 模拟歌单请求在切分段后返回；隐藏详情不应参与 NAS 返回。
    await container
        .read(playlistsViewModelProvider.notifier)
        .openPlaylist('fav');
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(container.read(libraryViewModelProvider).activeGroup, isNull);
    expect(container.read(playlistsViewModelProvider).detail?.id, 'fav');
    expect(await tester.binding.handlePopRoute(), isFalse);
  });

  testWidgets('更多菜单不打开歌单，取消删除不发请求，确认才删除', (tester) async {
    final playlists = _WritablePlaylistsRepository();
    await _pump(
      tester,
      library: FakeLibraryRepository(total: 0),
      playlists: playlists,
    );
    expect(find.byTooltip('删除'), findsNothing);
    await tester.tap(find.byTooltip('更多操作：测试歌单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除歌单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(
      playlists.calls.where((call) => call.startsWith('delete:')),
      isEmpty,
    );
    expect(playlists.calls.where((call) => call.startsWith('get:')), isEmpty);

    await tester.tap(find.byTooltip('更多操作：测试歌单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除歌单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(playlists.calls.where((call) => call == 'delete:fav'), hasLength(1));
    expect(find.text('测试歌单'), findsNothing);
    expect(find.text('创建第一个歌单'), findsOneWidget);
  });

  testWidgets('二倍字号下根导航、歌单操作与 NAS 工具均可用', (tester) async {
    await _pump(
      tester,
      library: FakeLibraryRepository(total: 3),
      playlists: _WritablePlaylistsRepository(),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('NAS 歌曲'));
    await tester.pumpAndSettle();
    expect(find.text('上传'), findsOneWidget);
    expect(find.text('扫描'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
