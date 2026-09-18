import 'chart.dart';
import 'chart_catalog.dart';

/// 仅保存榜单 ID 与展示偏好；目录变化时忽略缺席项，重新出现后恢复选择。
class ChartHomePreferences {
  const ChartHomePreferences({
    this.order = const [],
    this.visibility = const {},
  });

  final List<String> order;
  final Map<String, bool> visibility;

  List<Chart> sorted(List<Chart> charts) {
    final remaining = {for (final chart in charts) chart.id: chart};
    return [
      for (final id in order)
        if (remaining.remove(id) case final chart?) chart,
      ...remaining.values,
    ];
  }

  Set<String> defaults(List<Chart> charts) => {
    for (final chart in charts.where((c) => c.kind == 'spotify-personal'))
      chart.id,
    for (final chart in discoveryCharts(charts, 'featured')) chart.id,
  };

  bool enabled(String id, Set<String> defaults) =>
      visibility[id] ?? defaults.contains(id);

  List<Chart> selected(List<Chart> charts) {
    final selected = defaults(charts);
    return sorted(
      charts,
    ).where((chart) => enabled(chart.id, selected)).toList();
  }

  /// 旧偏好全关或目录缩减时，保留一个当前可用榜单，不改写其他模式的选择。
  ChartHomePreferences ensureOne(List<Chart> charts) =>
      charts.isNotEmpty && selected(charts).isEmpty
      ? show(sorted(charts).first.id, true)
      : this;

  List<Chart> home(List<Chart> charts) => ensureOne(charts).selected(charts);

  ChartHomePreferences show(String id, bool value) => ChartHomePreferences(
    order: order,
    visibility: Map.unmodifiable({...visibility, id: value}),
  );

  ChartHomePreferences reorder(List<Chart> charts, int oldIndex, int newIndex) {
    final ids = sorted(charts).map((chart) => chart.id).toList();
    if (newIndex > oldIndex) newIndex--;
    ids.insert(newIndex, ids.removeAt(oldIndex));
    return ChartHomePreferences(
      order: List.unmodifiable([
        ...ids,
        ...order.where((id) => !ids.contains(id)),
      ]),
      visibility: visibility,
    );
  }
}
