import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../models/chart.dart';
import 'charts_repository.dart';

final Provider<ChartsRepository> chartsRepositoryProvider =
    Provider<ChartsRepository>((ref) {
      return ApiChartsRepository(apiClient: ref.watch(apiClientProvider));
    });

class ApiChartsRepository implements ChartsRepository {
  const ApiChartsRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<Chart>> getCharts() async {
    final payload = await _apiClient.getMap('/charts');
    final list = payload['charts'];
    if (list is! List) return const <Chart>[];
    return list
        .whereType<Map<String, Object?>>()
        .map(Chart.fromJson)
        .toList(growable: false);
  }

  @override
  Future<ChartDetail> getChart(String id) async {
    return ChartDetail.fromJson(await _apiClient.getMap('/charts/$id'));
  }

  @override
  Future<void> playAll(String id, {int? startIndex}) async {
    await _apiClient.postMap(
      '/charts/$id/play',
      body: <String, Object?>{if (startIndex != null) 'startIndex': startIndex},
    );
  }
}
