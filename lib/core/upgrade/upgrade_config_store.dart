import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/models/app_update.dart';
import '../providers/infrastructure_providers.dart';
import '../storage/key_value_store.dart';
import '../storage/preferences_key_value_store.dart';

// 远程配置的本地粘性缓存：强制升级指令一旦到达过一次就落盘，之后断网/
// 屏蔽 GitHub 也照样执行——「拉不到就放行」只对从未收到过配置的全新安装
// 成立。解除强制同样靠下发更低的 minVersion 覆盖缓存。
final Provider<UpgradeConfigStore> upgradeConfigStoreProvider =
    Provider<UpgradeConfigStore>(
      (ref) => SharedPreferencesUpgradeConfigStore(
        preferences: ref.watch(keyValueStoreProvider),
      ),
    );

abstract class UpgradeConfigStore {
  Future<AppRemoteConfig?> read();

  Future<void> write(AppRemoteConfig config);
}

class SharedPreferencesUpgradeConfigStore implements UpgradeConfigStore {
  SharedPreferencesUpgradeConfigStore({KeyValueStore? preferences})
    : _preferences = preferences ?? createPreferencesKeyValueStore();

  static const _key = 'hmusic.upgrade.remoteConfig';

  final KeyValueStore _preferences;

  @override
  Future<AppRemoteConfig?> read() async {
    final raw = await _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return AppRemoteConfig.fromJson(
        decoded.map((k, v) => MapEntry('$k', v as Object?)),
      );
    } catch (_) {
      return null; // 缓存损坏当没有。
    }
  }

  @override
  Future<void> write(AppRemoteConfig config) {
    return _preferences.setString(
      _key,
      jsonEncode(<String, Object?>{
        'minVersion': config.minVersion,
        'notice': config.notice,
        'downloadUrl': config.downloadUrl,
        // 新版信息也一起落盘：GitHub 不通时「检查更新」靠它兜底（见
        // api_update_repository._releaseFromRemoteConfig）。
        'latestVersion': config.latestVersion,
        'apkUrl': config.apkUrl,
        'apkSize': config.apkSize,
      }),
    );
  }
}
