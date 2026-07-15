// 设置菜单行右侧的实时摘要（对齐 web loadSummary 的聚合口径）。
// 非服务端 DTO：各字段是并发拉多个接口后算好的展示字符串，取不到留空。
class SettingsSummary {
  const SettingsSummary({
    this.mi = '',
    this.devices = '',
    this.sources = '',
    this.downloads = '',
    this.tracks = '',
    this.config = '',
  });

  final String mi;
  final String devices;
  final String sources;
  final String downloads;
  final String tracks;
  final String config;
}
