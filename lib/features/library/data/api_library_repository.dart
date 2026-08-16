import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../models/library_item.dart';
import 'library_repository.dart';

final Provider<LibraryRepository> libraryRepositoryProvider =
    Provider<LibraryRepository>((ref) {
      return ApiLibraryRepository(apiClient: ref.watch(apiClientProvider));
    });

class ApiLibraryRepository implements LibraryRepository {
  const ApiLibraryRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<LibraryListResult> list({
    String? search,
    String? artist,
    String? album,
    String? folder,
    int limit = 50,
    int offset = 0,
  }) async {
    final payload = await _apiClient.getMap(
      '/library',
      query: <String, Object?>{
        if (search != null && search.isNotEmpty) 'search': search,
        if (artist != null) 'artist': artist,
        if (album != null) 'album': album,
        if (folder != null) 'folder': folder,
        'limit': limit,
        'offset': offset,
      },
    );
    return LibraryListResult.fromJson(payload);
  }

  @override
  Future<List<LibraryGroup>> groups(String by) async {
    final payload = await _apiClient.getMap(
      '/library/groups',
      query: <String, Object?>{'by': by},
    );
    return (payload['groups'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, Object?>>()
        .map(LibraryGroup.fromJson)
        .toList(growable: false);
  }

  @override
  Future<LibraryScanInfo> startScan() async {
    final payload = await _apiClient.postMap('/library/scan');
    return LibraryScanInfo.fromJson(
      (payload['scan'] as Map<String, Object?>?) ?? const <String, Object?>{},
    );
  }

  @override
  Future<void> remove(String id) async {
    await _apiClient.deleteMap('/library/$id');
  }

  @override
  Future<LibraryItem> upload(
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final payload = await _apiClient.uploadFile(
      '/library/upload',
      filePath: filePath,
      onProgress: onProgress,
    );
    return LibraryItem.fromJson(
      (payload['item'] as Map<String, Object?>?) ?? const <String, Object?>{},
    );
  }
}
