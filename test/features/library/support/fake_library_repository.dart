import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/features/library/data/library_repository.dart';
import 'package:hmusic/features/library/models/library_item.dart';

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
