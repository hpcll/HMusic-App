import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/infrastructure_providers.dart';
import '../../../core/storage/key_value_store.dart';
import '../models/chart_home_preferences.dart';

final chartHomePreferencesStoreProvider = Provider<ChartHomePreferencesStore>(
  (ref) => ChartHomePreferencesStore(ref.watch(keyValueStoreProvider)),
);

class ChartHomePreferencesStore {
  const ChartHomePreferencesStore(this._store);
  final KeyValueStore _store;
  static const key = 'hmusic.charts.home.v1';

  Future<ChartHomePreferences> read() async {
    try {
      final raw = await _store.getString(key);
      if (raw == null) return const ChartHomePreferences();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return ChartHomePreferences(
        order: List.unmodifiable(
          (data['order'] as List).whereType<String>().toSet(),
        ),
        visibility: Map.unmodifiable({
          for (final entry in (data['visibility'] as Map).entries)
            if (entry.key is String && entry.value is bool)
              entry.key as String: entry.value as bool,
        }),
      );
    } on Object {
      return const ChartHomePreferences();
    }
  }

  Future<void> write(ChartHomePreferences value) => _store.setString(
    key,
    jsonEncode({'order': value.order, 'visibility': value.visibility}),
  );
}
