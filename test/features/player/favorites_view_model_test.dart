import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/features/player/view_models/favorites_view_model.dart';
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

ProviderContainer _container(FakePlaylistsRepository repository) {
  final container = ProviderContainer(
    overrides: [playlistsRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('首次收藏：自动创建「我喜欢的音乐」再加歌', () async {
    final repository = FakePlaylistsRepository();
    final container = _container(repository);
    final viewModel = container.read(favoritesViewModelProvider.notifier);

    await viewModel.load();
    expect(container.read(favoritesViewModelProvider).playlist, isNull);
    expect(viewModel.itemFor(_track), isNull);

    await viewModel.toggle(_track);
    expect(repository.calls, contains('create:$kFavoritesPlaylistName'));
    expect(repository.calls, contains('add:fav:1'));
    expect(viewModel.itemFor(_track), isNotNull);
  });

  test('已收藏再点：按 itemId 从歌单移除', () async {
    final repository = FakePlaylistsRepository(
      favorites: const PlaylistDetail(
        id: 'fav',
        name: kFavoritesPlaylistName,
        items: <PlaylistItem>[PlaylistItem(id: 'item-1', track: _track)],
      ),
    );
    final container = _container(repository);
    final viewModel = container.read(favoritesViewModelProvider.notifier);

    await viewModel.load();
    expect(viewModel.itemFor(_track), isNotNull);

    await viewModel.toggle(_track);
    expect(repository.calls, contains('remove:fav:item-1'));
    expect(viewModel.itemFor(_track), isNull);
  });

  test('歌单已存在时收藏不重复建单；判重用 source:sourceTrackId', () async {
    final repository = FakePlaylistsRepository(
      favorites: const PlaylistDetail(id: 'fav', name: kFavoritesPlaylistName),
    );
    final container = _container(repository);
    final viewModel = container.read(favoritesViewModelProvider.notifier);

    await viewModel.load();
    // 同曲不同解析批次 id：判重仍按 source:sourceTrackId 命中。
    const resolvedAgain = HMusicTrack(
      id: 'tx:1#v2',
      source: 'tx',
      sourceTrackId: '1',
      title: '晴天',
      artist: '周杰伦',
    );

    await viewModel.toggle(_track);
    expect(repository.calls.where((c) => c.startsWith('create')), isEmpty);
    expect(viewModel.itemFor(resolvedAgain), isNotNull);
  });
}
