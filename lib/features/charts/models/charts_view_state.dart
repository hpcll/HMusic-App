import '../../../shared/models/hmusic_notice.dart';
import 'chart.dart';

enum ChartsStatus { initial, loading, loaded, error }

// 榜单页状态：卡片墙（active==null）与详情（active!=null）共用一个 state。
// previews: 缺键=预览加载中，值 null=拉取失败/空（回退描述），值列表=Top3。
class ChartsViewState {
  const ChartsViewState({
    this.status = ChartsStatus.initial,
    this.charts = const <Chart>[],
    this.previews = const <String, List<ChartEntry>?>{},
    this.active,
    this.detail,
    this.detailLoading = false,
    this.actingRank = 0,
    this.errorMessage,
    this.notice,
  });

  final ChartsStatus status;
  final List<Chart> charts;
  final Map<String, List<ChartEntry>?> previews;

  // 当前打开的榜单摘要；null = 卡片墙。
  final Chart? active;
  final ChartDetail? detail;
  final bool detailLoading;

  // 正在操作的条目 rank，防连点；-1 表示整榜播放占位。0 = 空闲。
  final int actingRank;

  final String? errorMessage;
  final HMusicNotice? notice;

  bool get isWall => active == null;

  ChartsViewState copyWith({
    ChartsStatus? status,
    List<Chart>? charts,
    Map<String, List<ChartEntry>?>? previews,
    Chart? active,
    ChartDetail? detail,
    bool? detailLoading,
    int? actingRank,
    String? errorMessage,
    HMusicNotice? notice,
    bool clearActive = false,
    bool clearDetail = false,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return ChartsViewState(
      status: status ?? this.status,
      charts: charts ?? this.charts,
      previews: previews ?? this.previews,
      active: clearActive ? null : (active ?? this.active),
      detail: clearDetail ? null : (detail ?? this.detail),
      detailLoading: detailLoading ?? this.detailLoading,
      actingRank: actingRank ?? this.actingRank,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}
