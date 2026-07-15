import '../models/lx_plugin.dart';

// LX 音源插件仓库（对齐 web SourcesSection）。列表 + 单条代码 + 健康态 +
// 订阅拉取 + 全量 upsert + 更新 + 测试 + 删除。
abstract interface class SourcesRepository {
  // 插件列表（不含 code）。
  Future<List<LxPlugin>> listPlugins();

  // 各插件健康态：id → ok/failed/unknown（GET /sources 的 health）。
  Future<Map<String, SourceHealth>> loadHealth();

  // 单条插件代码（编辑/切换启用需回填全量 upsert）。
  Future<String> getCode(String id);

  // 订阅链接代拉脚本，预填表单。
  Future<LxFetchResult> fetchFromUrl(String url);

  // 全量 upsert（保存/切换启用共用）。
  Future<void> savePlugin({
    required String id,
    required String name,
    required String code,
    required bool enabled,
    required String defaultQuality,
    String? sourceUrl,
  });

  // 按记住的 sourceUrl 重拉更新。
  Future<void> updatePlugin(String id);

  // 加载测试 → 提示消息。
  Future<String> testPlugin(String id);

  Future<void> deletePlugin(String id);
}
