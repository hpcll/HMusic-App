import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/features/library/data/api_library_repository.dart';
import 'package:hmusic/features/library/data/library_repository.dart';
import 'package:hmusic/features/library/models/library_item.dart';
import 'package:hmusic/features/library/models/library_view_state.dart';
import 'package:hmusic/features/library/view_models/library_view_model.dart';

LibraryItem _item(int i) => LibraryItem(
  id: 'lib$i',
  trackKey: 'local:$i',
  origin: 'scan',
  title: '本地曲目$i',
  artist: '歌手$i',
  track: HMusicTrack(
    id: 'local:$i',
    source: 'local',
    sourceTrackId: '$i',
    title: '本地曲目$i',
    artist: '歌手$i',
    url: 'http://nas/api/v1/proxy/local/local:$i.sig',
  ),
);

class FakeLibraryRepository implements LibraryRepository {
  FakeLibraryRepository({required this.total});

  final int total;
  final List<String> calls = <String>[];

  @override
  Future<LibraryListResult> list({
    String? search,
    String? artist,
    String? album,
    String? folder,
    int limit = 50,
    int offset = 0,
  }) async {
    calls.add('list:$search:$artist:$album:$folder:$limit:$offset');
    final end = (offset + limit).clamp(0, total);
    return LibraryListResult(
      items: [for (var i = offset; i < end; i++) _item(i)],
      total: total,
    );
  }

  @override
  Future<List<LibraryGroup>> groups(String by) async {
    calls.add('groups:$by');
    return const <LibraryGroup>[
      LibraryGroup(name: '林俊杰', count: 3),
      LibraryGroup(name: '', count: 1),
    ];
  }

  @override
  Future<LibraryScanInfo> startScan() async {
    calls.add('scan');
    return const LibraryScanInfo(status: 'scanning');
  }

  @override
  Future<void> remove(String id) async {
    calls.add('remove:$id');
  }

  @override
  Future<LibraryItem> upload(
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) async {
    calls.add('upload:$filePath');
    onProgress?.call(1, 1);
    return _item(0);
  }
}

ProviderContainer _container(FakeLibraryRepository repository) {
  final container = ProviderContainer(
    overrides: [libraryRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('load 拉首页；loadMore 按 offset 翻页并追加', () async {
    final repository = FakeLibraryRepository(total: 120);
    final container = _container(repository);
    final viewModel = container.read(libraryViewModelProvider.notifier);

    await viewModel.load();
    var state = container.read(libraryViewModelProvider);
    expect(state.items.length, 50);
    expect(state.total, 120);
    expect(state.hasMore, isTrue);

    await viewModel.loadMore();
    state = container.read(libraryViewModelProvider);
    expect(state.items.length, 100);
    expect(repository.calls, contains('list::null:null:null:50:50'));

    await viewModel.loadMore();
    state = container.read(libraryViewModelProvider);
    expect(state.items.length, 120);
    expect(state.hasMore, isFalse);

    // 已到底：不再发请求。
    final callsBefore = repository.calls.length;
    await viewModel.loadMore();
    expect(repository.calls.length, callsBefore);
  });

  test('搜索词经 load 重置列表并带 search 参数', () async {
    final repository = FakeLibraryRepository(total: 3);
    final container = _container(repository);
    final viewModel = container.read(libraryViewModelProvider.notifier);

    await viewModel.load(query: '晴天');

    expect(repository.calls, contains('list:晴天:null:null:null:50:0'));
    expect(container.read(libraryViewModelProvider).query, '晴天');
  });

  test('分类：切歌手分段拉聚合；点歌手按 artist 过滤；closeGroup 回聚合', () async {
    final repository = FakeLibraryRepository(total: 3);
    final container = _container(repository);
    final viewModel = container.read(libraryViewModelProvider.notifier);

    await viewModel.setSection(LibrarySection.artists);
    var state = container.read(libraryViewModelProvider);
    expect(repository.calls, contains('groups:artist'));
    expect(state.showsGroups, isTrue);
    expect(state.groups.length, 2);

    await viewModel.openGroup('林俊杰');
    state = container.read(libraryViewModelProvider);
    expect(state.showsGroups, isFalse);
    expect(repository.calls, contains('list::林俊杰:null:null:50:0'));

    viewModel.closeGroup();
    expect(container.read(libraryViewModelProvider).showsGroups, isTrue);
  });

  test('uploadFiles 逐个上传后刷新列表，isUploading 单飞复位', () async {
    final repository = FakeLibraryRepository(total: 2);
    final container = _container(repository);
    final viewModel = container.read(libraryViewModelProvider.notifier);

    await viewModel.uploadFiles(const [
      (path: '/tmp/a.mp3', name: 'a.mp3'),
      (path: '/tmp/b.flac', name: 'b.flac'),
    ]);

    expect(
      repository.calls,
      containsAll(['upload:/tmp/a.mp3', 'upload:/tmp/b.flac']),
    );
    // 结束后刷新列表且上传态复位。
    expect(repository.calls.last, startsWith('list:'));
    final state = container.read(libraryViewModelProvider);
    expect(state.isUploading, isFalse);
    expect(state.notice?.message, contains('已上传 2 首'));
  });

  test('文件夹分段：拉 folder 聚合，点根目录（空名）按 folder="" 过滤', () async {
    final repository = FakeLibraryRepository(total: 2);
    final container = _container(repository);
    final viewModel = container.read(libraryViewModelProvider.notifier);

    await viewModel.setSection(LibrarySection.folders);
    expect(repository.calls, contains('groups:folder'));

    // 空组名是合法值（根目录直属曲目），必须照样带上过滤参数。
    await viewModel.openGroup('');
    expect(repository.calls, contains('list::null:null::50:0'));
  });

  test('scan 触发后 scan 状态落地', () async {
    final repository = FakeLibraryRepository(total: 0);
    final container = _container(repository);
    final viewModel = container.read(libraryViewModelProvider.notifier);

    await viewModel.scan();

    expect(repository.calls, contains('scan'));
    expect(container.read(libraryViewModelProvider).scan?.isScanning, isTrue);
  });
}
