import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/api_update_repository.dart';
import '../app_version.dart';
import '../providers/infrastructure_providers.dart';

// 「有新版」小红点：进 App（以及每次从后台回到前台）静默检查一次，结果落盘，
// 设置入口（dock 的设置 tab + 设置菜单的「关于与更新」行）据此点红点。不弹窗、
// 不横幅——用户明确要求只在设置页提示，别每次开 App 都被挡一下。
//
// 为什么还要管「回到前台」：Android 上进程可以活好几天，build() 只跑一次；只在
// 冷启动查的话，常驻内存的 App 永远发现不了新版（用户反馈「app 自己其实没有
// 这个发现」）。
//
// 节流 1h：检查走 api.github.com（匿名接口每小时每 IP 60 次，共享代理容易被占满），
// 拉不到就退仓库 app-config.json 的三镜像 + 服务端中转。上次结果照旧从盘里读，
// 所以离线也显示上次发现的新版。
const Duration _checkInterval = Duration(hours: 1);
const String _latestKey = 'hmusic.appUpdate.latest';
const String _checkedAtKey = 'hmusic.appUpdate.checkedAt';

final NotifierProvider<AppUpdateBadge, String> appUpdateBadgeProvider =
    NotifierProvider<AppUpdateBadge, String>(AppUpdateBadge.new);

// state = 已知的最新版本号（空 = 不知道/没有更新渠道）。
class AppUpdateBadge extends Notifier<String> {
  AppLifecycleListener? _lifecycle;

  @override
  String build() {
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_boot()));
    ref.onDispose(() {
      _lifecycle?.dispose();
      _lifecycle = null;
    });
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

  // 立即查一次（开 App / 回到前台且节流窗口已过，或用户在设置里手动点检查更新）。
  Future<void> refresh() async {
    try {
      final release = await ref
          .read(updateRepositoryProvider)
          .latestAppRelease();
      await noteVersion(release?.version ?? '');
    } catch (_) {
      // 检查失败不打扰：红点保持上次结果（离线仍看得见上次发现的新版）。
    }
  }

  // 别处已经拿到最新版本号了（「关于与更新」进页静默加载 / 手动检查）：直接记账，
  // 不再自己发一次请求。红点与那一页说的必须是同一件事。
  Future<void> noteVersion(String version) async {
    if (version != state) state = version;
    try {
      final store = ref.read(keyValueStoreProvider);
      await store.setDouble(
        _checkedAtKey,
        DateTime.now().millisecondsSinceEpoch.toDouble(),
      );
      await store.setString(_latestKey, version);
    } catch (_) {
      // 落盘失败只影响「下次冷启还记不记得」，不该把调用方那次检查带崩。
    }
  }
}
