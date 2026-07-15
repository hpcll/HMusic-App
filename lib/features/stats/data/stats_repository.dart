import '../models/stats.dart';

// 统计数据契约：一次拉取聚合结果。
abstract interface class StatsRepository {
  Future<Stats> getStats();
}
