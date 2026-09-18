part of 'charts_view_model.dart';

mixin _ChartsPreviews on Notifier<ChartsViewState> {
  ChartDetailLoader get _loader;
  bool _isCurrent(int generation);

  // 隐藏项不再排队预取；已发请求仍由 loader 限流并允许详情复用。
  Future<void> _prefetchPreviews(List<Chart> charts, int generation) async {
    var cursor = 0;
    Future<void> worker() async {
      while (_isCurrent(generation) && cursor < charts.length) {
        final chart = charts[cursor++];
        final visible = [...state.personalCharts, ...state.discovery];
        if (!visible.any((item) => item.id == chart.id) ||
            state.previews.containsKey(chart.id)) {
          continue;
        }
        try {
          final detail = await _loader.read(chart.id);
          if (_isCurrent(generation)) {
            _writePreview(chart.id, detail.entries.take(3).toList());
          }
        } catch (error) {
          if (_isCurrent(generation)) {
            _writePreview(
              chart.id,
              null,
              error is ApiFailure ? error.message : '暂时无法加载，稍后重试',
            );
          }
        }
      }
    }

    await Future.wait([worker(), worker()]);
  }

  void _writePreview(String id, List<ChartEntry>? top, [String? error]) {
    final errors = {...state.previewErrors}..remove(id);
    if (error != null) errors[id] = error;
    state = state.copyWith(
      previews: <String, List<ChartEntry>?>{...state.previews, id: top},
      previewErrors: errors,
    );
  }
}
