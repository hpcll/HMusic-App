import '../models/library_item.dart';

abstract interface class LibraryRepository {
  Future<LibraryListResult> list({
    String? search,
    String? artist,
    String? album,
    String? folder,
    int limit,
    int offset,
  });

  Future<List<LibraryGroup>> groups(String by);

  Future<LibraryScanInfo> startScan();

  Future<void> remove(String id);

  Future<LibraryItem> upload(
    String filePath, {
    void Function(int sent, int total)? onProgress,
  });
}
