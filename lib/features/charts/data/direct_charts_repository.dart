import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/config/build_edition.dart';
import '../../../core/direct/music/platform_track_mapper.dart';
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
    final cached =
        _cache[chart.id] ??
        (chart.kind == 'spotify-public' ? await _savedChart(chart.id) : null);
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
      if (detail.kind == 'spotify-public') {
        try {
          await _store.update('spotifyCharts', (data) {
            data[detail.id] = detail.toJson();
          });
        } on Exception {
          // 缓存写入失败不妨碍展示刚取得的榜单，也不覆盖损坏的旧数据。
        }
      }
      return _cache[definition.chart.id] = detail;
    } on Exception {
      if (cached != null) {
        return cached.kind == 'spotify-public' ? _offlineChart(cached) : cached;
      }
      rethrow;
    } finally {
      final _ = _pending.remove(definition.chart.id);
    }
  }

  Future<ChartDetail?> _savedChart(String id) async {
    try {
      final data = musicMap((await _store.read('spotifyCharts'))[id]);
      if (data.isEmpty) return null;
      final detail = ChartDetail.fromJson(data);
      if (detail.id != id ||
          detail.kind != 'spotify-public' ||
          detail.updatedAt == null ||
          detail.entries.isEmpty) {
        return null;
      }
      return _cache[id] = detail;
    } on Object {
      // 无效缓存不冒充空榜单；继续尝试网络，保留原数据供排查。
      return null;
    }
  }

  ChartDetail _offlineChart(ChartDetail cached) {
    final savedAt = DateTime.fromMillisecondsSinceEpoch(cached.updatedAt!);
    final date =
        '${savedAt.year}-${savedAt.month.toString().padLeft(2, '0')}-'
        '${savedAt.day.toString().padLeft(2, '0')}';
    return ChartDetail(
      id: cached.id,
      name: cached.name,
      kind: cached.kind,
      description: cached.description,
      updatedAt: cached.updatedAt,
      entries: cached.entries,
      notice: '暂时无法更新 Spotify，正在显示 $date 保存的榜单。',
    );
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
