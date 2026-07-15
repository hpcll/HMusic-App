import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../models/stats.dart';
import 'stats_repository.dart';

final Provider<StatsRepository> statsRepositoryProvider =
    Provider<StatsRepository>((ref) {
      return ApiStatsRepository(apiClient: ref.watch(apiClientProvider));
    });

class ApiStatsRepository implements StatsRepository {
  const ApiStatsRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Stats> getStats() async {
    final payload = await _apiClient.getMap('/stats');
    final stats = payload['stats'];
    if (stats is! Map<String, Object?>) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidResponse,
        message: '统计数据格式异常',
      );
    }
    return Stats.fromJson(stats);
  }
}
