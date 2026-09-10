import 'chart.dart';
import 'chart_catalog.dart';

enum ChartsStatus { initial, loading, loaded, error }

// 榜单页状态：卡片墙（active==null）与详情（active!=null）共用一个 state。
// previews: 缺键=预览加载中，值 null=拉取失败/空（回退描述），值列表=Top3。
class ChartsViewState {
  const ChartsViewState({
    this.status = ChartsStatus.initial,
    this.charts = const <Chart>[],
    this.previews = const <String, List<ChartEntry>?>{},
    this.previewErrors = const <String, String>{},
    this.selectedSource = 'featured',
    this.active,
    this.detail,
    this.detailLoading = false,
    this.actingRank = 0,
    this.errorMessage,
  });

  final ChartsStatus status;
  final List<Chart> charts;
  final Map<String, List<ChartEntry>?> previews;
  final Map<String, String> previewErrors;
  final String selectedSource;

  List<Chart> get personalCharts =>
      charts.where((chart) => chart.kind == 'spotify-personal').toList();
  List<Chart> get discovery => discoveryCharts(charts, selectedSource);

  // 当前打开的榜单摘要；null = 卡片墙。
  final Chart? active;
  final ChartDetail? detail;
  final bool detailLoading;

  // 正在操作的条目 rank，防连点；-1 表示整榜播放占位。0 = 空闲。
  final int actingRank;

  final String? errorMessage;

  bool get isWall => active == null;

  ChartsViewState copyWith({
    ChartsStatus? status,
    List<Chart>? charts,
    Map<String, List<ChartEntry>?>? previews,
    Map<String, String>? previewErrors,
    String? selectedSource,
    Chart? active,
    ChartDetail? detail,
    bool? detailLoading,
    int? actingRank,
    String? errorMessage,
    bool clearActive = false,
    bool clearDetail = false,
    bool clearError = false,
  }) {
    return ChartsViewState(
      status: status ?? this.status,
      charts: charts ?? this.charts,
      previews: previews ?? this.previews,
      previewErrors: previewErrors ?? this.previewErrors,
      selectedSource: selectedSource ?? this.selectedSource,
      active: clearActive ? null : (active ?? this.active),
      detail: clearDetail ? null : (detail ?? this.detail),
      detailLoading: detailLoading ?? this.detailLoading,
      actingRank: actingRank ?? this.actingRank,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
