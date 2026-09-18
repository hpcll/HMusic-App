import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/downloads/download_index.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/features/charts/data/api_charts_repository.dart';
import 'package:hmusic/features/charts/data/charts_repository.dart';
import 'package:hmusic/features/charts/models/chart.dart';
import 'package:hmusic/features/charts/view_models/charts_view_model.dart';
import 'package:hmusic/features/settings/models/download_record.dart';
import 'package:mocktail/mocktail.dart';

class _Repository extends Mock implements ChartsRepository {}

class _Downloads extends DownloadIndex {
  @override
  Map<String, DownloadStatus> build() => const {};
  @override
  Future<void> refresh() async {}
}

const _charts = <Chart>[
  Chart(id: 'spotify-top-short', name: '最近常听', kind: 'spotify-personal'),
  Chart(id: 'spotify-top-medium', name: '半年常听', kind: 'spotify-personal'),
  Chart(id: 'spotify-top-long', name: '长期常听', kind: 'spotify-personal'),
  Chart(id: 'family', name: '家庭热播', kind: 'family'),
  Chart(id: 'wy-hot', name: '热歌榜', kind: 'netease'),
  Chart(id: 'wy-new', name: '新歌榜', kind: 'netease'),
];

ChartDetail _detail(String id) => ChartDetail(
  id: id,
  name: id,
  kind: _charts.firstWhere((chart) => chart.id == id).kind,
  entries: [ChartEntry(rank: 1, title: '$id 第一首', artist: '歌手')],
);

void main() {
  late _Repository repository;
  late ProviderContainer container;
  late ChartsViewModel model;

  setUp(() {
    repository = _Repository();
    when(repository.getCharts).thenAnswer((_) async => _charts);
    when(() => repository.getChart(any())).thenAnswer(
      (call) async => _detail(call.positionalArguments[0] as String),
    );
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        chartsRepositoryProvider.overrideWithValue(repository),
        downloadIndexProvider.overrideWith(_Downloads.new),
      ],
    );
    model = container.read(chartsViewModelProvider.notifier);
  });
  tearDown(() => container.dispose());

  test('首次进入自动填充三个 Spotify 卡片，打开详情复用已加载曲目', () async {
    await model.load();
    final state = container.read(chartsViewModelProvider);
    expect(state.isWall, isTrue);
    for (final chart in _charts.take(3)) {
      expect(state.previews[chart.id]?.first.title, '${chart.id} 第一首');
    }
    verifyNever(() => repository.getChart('wy-new'));
    await model.openChart(_charts.first);
    expect(
      container.read(chartsViewModelProvider).detail?.entries,
      hasLength(1),
    );
    verify(() => repository.getChart('spotify-top-short')).called(1);
    model.back();
    await model.selectSource('netease');
    expect(container.read(chartsViewModelProvider).discovery, hasLength(2));
    verify(() => repository.getChart('wy-new')).called(1);
  });

  test('一个个人榜单失败不影响其他卡片，重试可恢复', () async {
    when(() => repository.getChart('spotify-top-medium')).thenThrow(
      const ApiFailure(kind: ApiFailureKind.server, message: 'Spotify 暂时限流'),
    );
    await model.load();
    var state = container.read(chartsViewModelProvider);
    expect(state.previewErrors['spotify-top-medium'], 'Spotify 暂时限流');
    expect(state.previews['spotify-top-long'], hasLength(1));
    when(
      () => repository.getChart('spotify-top-medium'),
    ).thenAnswer((_) async => _detail('spotify-top-medium'));
    await model.retryPreview(_charts[1]);
    state = container.read(chartsViewModelProvider);
    expect(state.previewErrors, isEmpty);
    expect(state.previews['spotify-top-medium'], hasLength(1));
    verify(() => repository.getChart('spotify-top-short')).called(1);
  });

  test('快速返回后，迟到详情不能重新打开榜单', () async {
    await model.load();
    final pending = Completer<ChartDetail>();
    when(() => repository.getChart('wy-new')).thenAnswer((_) => pending.future);
    final opening = model.openChart(_charts.last);
    model.back();
    pending.complete(_detail('wy-new'));
    await opening;
    final state = container.read(chartsViewModelProvider);
    expect(state.isWall, isTrue);
    expect(state.detail, isNull);
    expect(state.detailLoading, isFalse);
  });

  test('后发刷新优先，旧目录不能覆盖新账号的列表', () async {
    final old = Completer<List<Chart>>();
    when(repository.getCharts).thenAnswer((_) => old.future);
    final loading = model.load();
    when(repository.getCharts).thenAnswer((_) async => const <Chart>[]);
    await model.load();
    old.complete(_charts);
    await loading;
    final state = container.read(chartsViewModelProvider);
    expect(state.charts, isEmpty);
    expect(state.previews, isEmpty);
  });

  test('并发预取最多两个请求，切换账号后旧预览不能回填', () async {
    final requests = <String, Completer<ChartDetail>>{};
    when(() => repository.getChart(any())).thenAnswer((call) {
      final id = call.positionalArguments[0] as String;
      return (requests[id] = Completer<ChartDetail>()).future;
    });
    final loading = model.load();
    await Future<void>.delayed(Duration.zero);
    expect(requests, hasLength(2));
    final opening = model.openChart(_charts.first);
    when(repository.getCharts).thenAnswer((_) async => const <Chart>[]);
    await model.load();
    for (final entry in requests.entries) {
      entry.value.complete(_detail(entry.key));
    }
    await Future.wait([loading, opening]);
    expect(container.read(chartsViewModelProvider).previews, isEmpty);
    expect(container.read(chartsViewModelProvider).isWall, isTrue);
    expect(container.read(chartsViewModelProvider).detail, isNull);
    expect(requests, hasLength(2));
  });

  test('预取、切换平台和打开详情共用两个请求名额', () async {
    final releases = <void Function()>[];
    var active = 0;
    var peak = 0;
    when(() => repository.getChart(any())).thenAnswer((call) {
      final id = call.positionalArguments[0] as String;
      final pending = Completer<ChartDetail>();
      active++;
      if (active > peak) peak = active;
      releases.add(() {
        active--;
        pending.complete(_detail(id));
      });
      return pending.future;
    });
    final loading = model.load();
    await Future<void>.delayed(Duration.zero);
    expect(releases, hasLength(2));
    final selecting = model.selectSource('netease');
    final opening = model.openChart(_charts.last);
    while (releases.isNotEmpty) {
      final batch = List<void Function()>.of(releases);
      releases.clear();
      for (final release in batch) {
        release();
      }
      await Future<void>.delayed(Duration.zero);
    }
    await Future.wait([loading, selecting, opening]);
    expect(peak, 2);
    final state = container.read(chartsViewModelProvider);
    expect(state.detail?.id, 'wy-new');
    expect(state.previews['spotify-top-long'], hasLength(1));
    verify(() => repository.getChart('wy-new')).called(1);
  });

  test('刷新取消尚未发出的旧详情，不残留加载或错误状态', () async {
    final pending = Completer<ChartDetail>();
    when(() => repository.getChart(any())).thenAnswer((_) => pending.future);
    final loading = model.load();
    await Future<void>.delayed(Duration.zero);
    final opening = model.openChart(_charts.last);
    when(repository.getCharts).thenAnswer((_) async => const <Chart>[]);
    await model.load();
    await opening;
    pending.complete(_detail('spotify-top-short'));
    await loading;
    verifyNever(() => repository.getChart('wy-new'));
    final state = container.read(chartsViewModelProvider);
    expect(state.previews, isEmpty);
    expect(state.isWall, isTrue);
    expect(state.errorMessage, isNull);
    expect(state.detailLoading, isFalse);
  });

  test('预览在 provider 销毁后完成不会写入已销毁状态', () async {
    final pending = Completer<ChartDetail>();
    when(repository.getCharts).thenAnswer((_) async => [_charts.first]);
    when(() => repository.getChart(any())).thenAnswer((_) => pending.future);
    final loading = model.load();
    await Future<void>.delayed(Duration.zero);
    container.invalidate(chartsViewModelProvider);
    pending.complete(_detail('spotify-top-short'));
    await expectLater(loading, completes);
  });
}
