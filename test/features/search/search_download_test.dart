import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/features/search/view_models/search_view_model.dart';
import 'package:hmusic/features/settings/data/api_downloads_repository.dart';
import 'package:hmusic/features/settings/data/downloads_repository.dart';
import 'package:hmusic/features/settings/models/download_record.dart';

class _FakeDownloadsRepository implements DownloadsRepository {
  final List<({HMusicTrack track, String? quality})> started =
      <({HMusicTrack track, String? quality})>[];
  bool fail = false;

  @override
  Future<void> start(HMusicTrack track, {String? quality}) async {
    if (fail) {
      throw const ApiFailure(kind: ApiFailureKind.unknown, message: '下载失败');
    }
    started.add((track: track, quality: quality));
  }

  @override
  Future<List<DownloadRecord>> list() async => const <DownloadRecord>[];

  @override
  Future<void> remove(String id) async {}

  @override
  Future<void> retry(HMusicTrack track) async {}
}

const _track = HMusicTrack(
  id: 'tx:1',
  source: 'tx',
  sourceTrackId: '1',
  title: '晴天',
  artist: '周杰伦',
);

ProviderContainer _container(_FakeDownloadsRepository repo) {
  final container = ProviderContainer(
    overrides: [downloadsRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('选具体音质下载：带 quality 发起，成功提示', () async {
    final repo = _FakeDownloadsRepository();
    final container = _container(repo);
    final vm = container.read(searchViewModelProvider.notifier);

    await vm.download(_track, quality: 'flac');

    expect(repo.started.single.quality, 'flac');
    expect(repo.started.single.track.id, 'tx:1');
    expect(
      container.read(searchViewModelProvider).notice?.message,
      contains('已开始下载'),
    );
  });

  test('服务器默认音质：quality 省略', () async {
    final repo = _FakeDownloadsRepository();
    final container = _container(repo);
    final vm = container.read(searchViewModelProvider.notifier);

    await vm.download(_track);

    expect(repo.started.single.quality, isNull);
  });

  test('下载失败：如实报错，不误报成功', () async {
    final repo = _FakeDownloadsRepository()..fail = true;
    final container = _container(repo);
    final vm = container.read(searchViewModelProvider.notifier);

    await vm.download(_track, quality: '320k');

    final state = container.read(searchViewModelProvider);
    expect(state.errorMessage, '下载失败');
    expect(state.notice, isNull);
  });
}
