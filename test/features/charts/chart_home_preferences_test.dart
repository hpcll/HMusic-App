import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/features/charts/data/api_charts_repository.dart';
import 'package:hmusic/features/charts/data/chart_home_preferences_store.dart';
import 'package:hmusic/features/charts/data/charts_repository.dart';
import 'package:hmusic/features/charts/models/chart.dart';
import 'package:hmusic/features/charts/models/chart_home_preferences.dart';
import 'package:hmusic/features/charts/view_models/chart_home_preferences_view_model.dart';
import 'package:hmusic/features/charts/view_models/charts_view_model.dart';

const charts = [
  Chart(id: 'sp', name: 'Spotify', kind: 'spotify-public'),
  Chart(id: 'wy', name: '热歌', kind: 'netease'),
  Chart(id: 'wy-new', name: '新歌', kind: 'netease'),
];

class HomeChartsRepository extends Fake implements ChartsRepository {
  final requests = <String>[];
  @override
  Future<List<Chart>> getCharts() async => charts;
  @override
  Future<ChartDetail> getChart(String id) async {
    requests.add(id);
    return ChartDetail(id: id, name: id, kind: 'netease');
  }

  @override
  Future<HMusicPlaybackState> playAll(String id, {int? startIndex}) =>
      throw UnimplementedError();
}

void main() {
  test(
    'last recommendation cannot be saved hidden; legacy and reduced catalog recover',
    () async {
      final none = const ChartHomePreferences()
          .show('sp', false)
          .show('wy', false);
      expect(none.selected(charts), isEmpty);
      expect(none.home(charts).single.id, 'sp');
      expect(none.home([charts[1]]).single.id, 'wy');
      expect(none.home([]), isEmpty);
      final storage = MemoryKeyValueStore();
      final container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      await expectLater(
        container
            .read(chartHomePreferencesProvider.notifier)
            .save(none, charts: charts),
        throwsStateError,
      );
      expect(await storage.getString(ChartHomePreferencesStore.key), isNull);
    },
  );

  test('defaults, hide, enable nonfeatured, reorder and absent IDs', () {
    const defaults = ChartHomePreferences();
    expect(defaults.home(charts).map((c) => c.id), ['sp', 'wy']);
    final edited = defaults
        .show('sp', false)
        .show('wy-new', true)
        .reorder(charts, 2, 0);
    expect(edited.home(charts).map((c) => c.id), ['wy-new', 'wy']);
    expect(edited.home([charts[1]]).single.id, 'wy');
    expect(edited.home(charts).map((c) => c.id), ['wy-new', 'wy']);
  });

  test(
    'restore before prefetch, hidden chart still accessible by platform, reset',
    () async {
      final storage = MemoryKeyValueStore();
      await ChartHomePreferencesStore(
        storage,
      ).write(const ChartHomePreferences().show('sp', false));
      final repository = HomeChartsRepository();
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(storage),
          chartsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final model = container.read(chartsViewModelProvider.notifier);
      await model.load();
      expect(repository.requests, ['wy']);
      expect(container.read(chartsViewModelProvider).discovery.single.id, 'wy');
      await model.selectSource('spotify-public');
      expect(container.read(chartsViewModelProvider).discovery.single.id, 'sp');
      await model.selectSource('featured');
      await container
          .read(chartHomePreferencesProvider.notifier)
          .save(const ChartHomePreferences(), charts: charts);
      expect(
        container.read(chartsViewModelProvider).discovery.map((c) => c.id),
        ['sp', 'wy'],
      );
      expect(
        (await ChartHomePreferencesStore(storage).read()).visibility,
        isEmpty,
      );
    },
  );

  test(
    'preferences survive container restart and corrupt storage falls back',
    () async {
      final storage = MemoryKeyValueStore();
      final first = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(storage)],
      );
      await first
          .read(chartHomePreferencesProvider.notifier)
          .save(
            const ChartHomePreferences()
                .show('sp', false)
                .reorder(charts, 1, 0),
            charts: charts,
          );
      first.dispose();
      final second = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(storage)],
      );
      addTearDown(second.dispose);
      await second.read(chartHomePreferencesProvider.notifier).restore();
      expect(second.read(chartHomePreferencesProvider).order.first, 'wy');
      expect(
        second.read(chartHomePreferencesProvider).visibility['sp'],
        isFalse,
      );
      await storage.setString(ChartHomePreferencesStore.key, '{broken');
      expect(
        (await ChartHomePreferencesStore(storage).read()).home(charts),
        hasLength(2),
      );
    },
  );
}
