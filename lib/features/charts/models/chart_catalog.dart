import 'chart.dart';

const chartSources = <(String, String)>[
  ('featured', '精选'),
  ('spotify-public', 'Spotify'),
  ('netease', '网易云音乐'),
  ('qq', 'QQ音乐'),
  ('apple', 'Apple Music'),
  ('family', 'HMusic'),
];

String chartSourceLabel(Chart chart) {
  if (chart.kind == 'spotify-personal') {
    return chart.description?.replaceFirst(RegExp(r'^Spotify\s*'), '') ??
        'Spotify 常听';
  }
  return chartSources
      .firstWhere(
        (entry) => entry.$1 == chart.kind,
        orElse: () => (chart.kind, chart.kind),
      )
      .$2;
}

List<Chart> discoveryCharts(List<Chart> charts, String source) {
  final public = charts.where((chart) => chart.kind != 'spotify-personal');
  if (source != 'featured') {
    return public.where((chart) => chart.kind == source).toList();
  }
  final kinds = <String>{};
  return public.where((chart) => kinds.add(chart.kind)).toList();
}
