import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/api_update_repository.dart';
import '../../features/settings/models/app_update.dart';
import '../app_version.dart';
import 'upgrade_config_store.dart';

// 强制升级门：两路准入判定，任一要求高于当前版本即封锁进壳。
//   1. 已连接服务端要求的 minAppVersion（/system/info 下发，请求层 403 兜底）
//      ——门槛由部署者掌握，用于挡住会写坏其数据的 App 版本、统一多客户端版本、
//      或声明不兼容的 API 改动；换一台兼容的服务端即可解除（强升页留了逃生口）。
//   2. App 仓库 app-config.json 的 minVersion——发版方（我方）的全局开关，
//      不发服务端新版也能召回坏版本（Gitee/raw/jsDelivr 多镜像 + 服务端中转，
//      取到即落盘做粘性执行，见 repository 与 upgrade_config_store）。
// 判定失败（探测不到/无配置）一律放行——门只在明确要求时关。
class UpgradeGateState {
  const UpgradeGateState({
    this.required = false,
    this.requiredVersion = '',
    this.fromServer = false,
    this.notice,
    this.downloadUrl,
    this.checked = false,
  });

  final bool required;

  // 触发封锁的最低版本要求（展示用）。
  final String requiredVersion;

  // true = 服务端要求（换服务器可解）；false = 官方远程配置要求。
  final bool fromServer;
  final String? notice;
  final String? downloadUrl;
  final bool checked;
}

final NotifierProvider<UpgradeGate, UpgradeGateState> upgradeGateProvider =
    NotifierProvider<UpgradeGate, UpgradeGateState>(UpgradeGate.new);

class UpgradeGate extends Notifier<UpgradeGateState> {
  bool _inFlight = false;

  @override
  UpgradeGateState build() => const UpgradeGateState();

  // 进壳后调用（AppShell build 首帧 / 强升页「重新检测」）。两路并发，
  // 单路失败不拦另一路；in-flight 挡重入（壳可能多次 build）。
  Future<void> check() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final repository = ref.read(updateRepositoryProvider);
      final results = await Future.wait(<Future<UpgradeGateState?>>[
        _checkServer(repository),
        _checkRemote(repository),
      ]);
      // 服务端要求优先展示（换服务器可解，提示更具体）。
      final hit = results[0] ?? results[1];
      state = hit ?? const UpgradeGateState(checked: true);
    } finally {
      _inFlight = false;
    }
  }

  // 换服务器前清门：新 server base 连上后由下一次 check() 重新判定，
  // 否则旧判定会把用户弹回强升页、连接页都进不去。
  void reset() {
    state = const UpgradeGateState();
  }

  // 服务端按版本门槛拒绝服务时当场关门（403，由 ApiClient 回调）。
  // 与 check() 的分工：check 在进壳时主动探一次，这条在任何业务请求撞上时兜底。
  void rejectedByServer(String minAppVersion) {
    final required = minAppVersion.isEmpty ? '更高版本' : minAppVersion;
    if (state.required && state.requiredVersion == required) return;
    state = UpgradeGateState(
      required: true,
      requiredVersion: required,
      fromServer: true,
      checked: true,
    );
  }

  Future<UpgradeGateState?> _checkServer(UpdateRepository repository) async {
    try {
      final info = await repository.serverInfo();
      if (info.minAppVersion.isEmpty) return null;
      if (!isNewerVersion(info.minAppVersion, kAppVersion)) return null;
      return UpgradeGateState(
        required: true,
        requiredVersion: info.minAppVersion,
        fromServer: true,
        checked: true,
      );
    } catch (_) {
      return null; // 探测不到按放行。
    }
  }

  Future<UpgradeGateState?> _checkRemote(UpdateRepository repository) async {
    try {
      final store = ref.read(upgradeConfigStoreProvider);
      // 在线取到就落盘（粘性执行的来源）；取不到用上次落盘的旧配置——
      // 强制指令到达过一次就一直有效，断网/屏蔽源站躲不掉。
      // 落盘/读盘自身失败不影响判定（宁可少粘性，不丢在线结果）。
      var config = await repository.remoteAppConfig();
      if (config != null) {
        try {
          await store.write(config);
        } catch (_) {}
      } else {
        try {
          config = await store.read();
        } catch (_) {}
      }
      if (config == null || config.minVersion.isEmpty) return null;
      if (!isNewerVersion(config.minVersion, kAppVersion)) return null;
      return UpgradeGateState(
        required: true,
        requiredVersion: config.minVersion,
        fromServer: false,
        notice: config.notice,
        downloadUrl: config.downloadUrl,
        checked: true,
      );
    } catch (_) {
      return null;
    }
  }
}
