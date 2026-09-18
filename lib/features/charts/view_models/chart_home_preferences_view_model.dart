import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/async/serial_executor.dart';
import '../data/chart_home_preferences_store.dart';
import '../models/chart.dart';
import '../models/chart_home_preferences.dart';

final chartHomePreferencesProvider =
    NotifierProvider<ChartHomePreferencesViewModel, ChartHomePreferences>(
      ChartHomePreferencesViewModel.new,
    );

class ChartHomePreferencesViewModel extends Notifier<ChartHomePreferences> {
  final _writes = SerialExecutor();
  Future<void>? _loading;

  @override
  ChartHomePreferences build() => const ChartHomePreferences();

  Future<void> restore() => _loading ??= _restore();

  Future<void> _restore() async {
    final saved = await ref.read(chartHomePreferencesStoreProvider).read();
    if (ref.mounted) state = saved;
  }

  Future<void> save(
    ChartHomePreferences value, {
    required List<Chart> charts,
  }) async {
    if (charts.isEmpty || value.selected(charts).isEmpty) {
      throw StateError('首页至少保留一个推荐榜单');
    }
    await restore();
    if (!ref.mounted) return;
    final store = ref.read(chartHomePreferencesStoreProvider);
    await _writes.run(() async {
      await store.write(value);
      if (ref.mounted) state = value;
    });
  }
}
