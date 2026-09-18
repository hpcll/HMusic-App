import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/direct/direct_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/playback/playback_mode.dart';
import '../../../core/playback/playback_mode_controller.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../models/search_result.dart';
import 'direct_search_repository.dart';
import 'search_repository.dart';

final Provider<SearchRepository> searchRepositoryProvider =
    Provider<SearchRepository>((ref) {
      if (ref.watch(playbackModeProvider).usesLocalBackend) {
        return DirectSearchRepository(
          ref.watch(directMusicSearchProvider),
          ref.watch(directLocalStoreProvider),
        );
      }
      return ApiSearchRepository(apiClient: ref.watch(apiClientProvider));
    });

class ApiSearchRepository implements SearchRepository {
  const ApiSearchRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<SearchResult> search(String query) async {
    final payload = await _apiClient.getMap(
      '/search',
      query: <String, Object?>{'q': query},
    );
    return SearchResult.fromJson(payload);
  }
}
