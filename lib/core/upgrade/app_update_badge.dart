import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/api_update_repository.dart';
import '../app_version.dart';
import '../providers/infrastructure_providers.dart';

// 「有新版」小红点：进 App 静默检一次，结果落盘，设置入口（dock 的设置 tab +
// 设置菜单的「关于与更新」行）据此点红点。不弹窗、不横幅——用户明确要求只在
// 设置页提示，别每次开 App 都被挡一下。
//
// 节流 6h：检查要走 api.github.com（大陆常连不上），每次冷启都打一遍既慢又
// 没意义；上次结果照旧从盘里读，所以离线也能显示上次发现的新版。
const Duration _checkInterval = Duration(hours: 6);
const String _latestKey = 'hmusic.appUpdate.latest';
const String _checkedAtKey = 'hmusic.appUpdate.checkedAt';

final NotifierProvider<AppUpdateBadge, String> appUpdateBadgeProvider =
    NotifierProvider<AppUpdateBadge, String>(AppUpdateBadge.new);

// state = 已知的最新版本号（空 = 不知道/没有更新渠道）。
class AppUpdateBadge extends Notifier<String> {
  @override
  String build() {
    unawaited(_boot());
    return '';
  }

  // 有比当前版本更新的版本可下 = 点红点。
  bool get hasUpdate => state.isNotEmpty && isNewerThanCurrent(state);

  static bool isNewerThanCurrent(String version) {
    // 版本比较口径与「关于与更新」页一致（v 前缀无视，逐段比数字）。
    final latest = version.replaceFirst(RegExp('^v', caseSensitive: false), '');
    final parts = latest.split('.');
    final current = kAppVersion.split('.');
    final length = parts.length > current.length
        ? parts.length
        : current.length;
    for (var i = 0; i < length; i += 1) {
      final a = i < parts.length ? int.tryParse(parts[i]) ?? 0 : 0;
      final b = i < current.length ? int.tryParse(current[i]) ?? 0 : 0;
      if (a != b) return a > b;
    }
    return false;
  }

  Future<void> _boot() async {
    final store = ref.read(keyValueStoreProvider);
    final cached = await store.getString(_latestKey);
    if (cached != null && cached.isNotEmpty && cached != state) state = cached;
    final checkedAt = await store.getDouble(_checkedAtKey) ?? 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - checkedAt.toInt();
    if (elapsed < _checkInterval.inMilliseconds) return;
    await refresh();
  }

  // 立即查一次（开 App 的节流窗口过期时，或用户在设置里手动点检查更新之后）。
  Future<void> refresh() async {
    final store = ref.read(keyValueStoreProvider);
    try {
      final release = await ref
          .read(updateRepositoryProvider)
          .latestAppRelease();
      await store.setDouble(
        _checkedAtKey,
        DateTime.now().millisecondsSinceEpoch.toDouble(),
      );
      final version = release?.version ?? '';
      await store.setString(_latestKey, version);
      if (version != state) state = version;
    } catch (_) {
      // 检查失败不打扰：红点保持上次结果（离线仍看得见上次发现的新版）。
    }
  }
}
