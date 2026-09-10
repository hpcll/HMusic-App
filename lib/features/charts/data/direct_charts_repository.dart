import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/config/build_edition.dart';
import '../../../core/direct/storage/direct_local_store.dart';
import '../../../core/network/api_failure.dart';
import '../models/chart.dart';
import '../models/direct_chart_catalog.dart';
import 'charts_repository.dart';
import 'direct_chart_playback.dart';
import 'direct_chart_source.dart';
import 'direct_family_chart.dart';

class DirectChartsRepository implements ChartsRepository {
  DirectChartsRepository({
    required DirectChartSource source,
    required DirectChartPlayback playback,
    required DirectLocalStore store,
    bool includeSpotify = !BuildEdition.isStore,
    DateTime Function()? now,
  }) : _source = source,
       _playback = playback,
       _store = store,
       _definitions = directChartCatalog(includeSpotify: includeSpotify),
       _now = now ?? DateTime.now;
  final DirectChartSource _source;
  final DirectChartPlayback _playback;
  final DirectLocalStore _store;
  final List<DirectChartDefinition> _definitions;
  final DateTime Function() _now;
  final _cache = <String, ChartDetail>{};
  final _pending = <String, Future<ChartDetail>>{};

  void dispose() => _playback.dispose();

  @override
  Future<List<Chart>> getCharts() async => [
    for (final definition in _definitions) definition.chart,
  ];

  @override
  Future<ChartDetail> getChart(String id) async {
    final definition = _definitions
        .where(
          (definition) =>
              definition.chart.id == id ||
              (definition.chart.kind == 'netease' &&
                  'wy-${definition.upstreamId}' == id),
        )
        .firstOrNull;
    if (definition == null) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '直连模式不提供此榜单',
      );
    }
    final chart = definition.chart;
    if (chart.kind == 'family') {
      return _detail(
        chart,
        directFamilyEntries(await _store.read('history'), _now()),
      );
    }
    final cached = _cache[chart.id];
    if (cached != null &&
        _now().millisecondsSinceEpoch - cached.updatedAt! <
            const Duration(days: 1).inMilliseconds) {
      return cached;
    }
    return _pending[chart.id] ??= _fetch(definition, cached);
  }

  Future<ChartDetail> _fetch(
    DirectChartDefinition definition,
    ChartDetail? cached,
  ) async {
    try {
      final detail = _detail(definition.chart, await _source.fetch(definition));
      return _cache[definition.chart.id] = detail;
    } on Exception {
      if (cached != null) return cached;
      rethrow;
    } finally {
      final _ = _pending.remove(definition.chart.id);
    }
  }

  ChartDetail _detail(Chart chart, List<ChartEntry> entries) => ChartDetail(
    id: chart.id,
    name: chart.name,
    kind: chart.kind,
    description: chart.description,
    updatedAt: _now().millisecondsSinceEpoch,
    entries: entries,
  );

  @override
  Future<HMusicPlaybackState> playAll(String id, {int? startIndex}) async {
    final detail = await getChart(id);
    return _playback.play(detail, startIndex ?? 0);
  }
}
