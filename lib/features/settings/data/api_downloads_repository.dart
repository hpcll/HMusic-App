import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/hmusic_track.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../models/download_record.dart';
import 'downloads_repository.dart';

final Provider<DownloadsRepository> downloadsRepositoryProvider =
    Provider<DownloadsRepository>((ref) {
      return ApiDownloadsRepository(apiClient: ref.watch(apiClientProvider));
    });

class ApiDownloadsRepository implements DownloadsRepository {
  const ApiDownloadsRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<DownloadRecord>> list() async {
    final payload = await _apiClient.getMap('/downloads');
    final items = payload['downloads'];
    if (items is! List<Object?>) return const <DownloadRecord>[];
    return items
        .whereType<Map<String, Object?>>()
        .map(DownloadRecord.fromJson)
        .toList();
  }

  @override
  Future<void> remove(String id) async {
    await _apiClient.deleteMap('/downloads/${Uri.encodeComponent(id)}');
  }

  @override
  Future<void> retry(HMusicTrack track) async {
    await _apiClient.postMap(
      '/downloads',
      body: <String, Object?>{'track': track.toJson()},
    );
  }
}
