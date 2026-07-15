// 运行配置的选项常量表（下拉标签 + 菜单摘要共用）。
// 值与服务端枚举字面量一致；未知值走 label 回退显示原始字符串。
const List<(String, String)> kQualityOptions = <(String, String)>[
  ('128k', '128k'),
  ('320k', '320k'),
  ('flac', 'FLAC'),
  ('hires', 'Hi-Res'),
];

const List<(String, String)> kSearchStrategyOptions = <(String, String)>[
  ('qqFirst', 'QQ 优先'),
  ('kuwoFirst', '酷我优先'),
  ('neteaseFirst', '网易云优先'),
];

const List<(String, String)> kResolveStrategyOptions = <(String, String)>[
  ('originalFirst', '原始结果优先'),
  ('qqFirst', 'QQ 优先'),
  ('kuwoFirst', '酷我优先'),
  ('neteaseFirst', '网易云优先'),
];

String configOptionLabel(List<(String, String)> options, String value) {
  for (final (v, label) in options) {
    if (v == value) return label;
  }
  return value;
}
