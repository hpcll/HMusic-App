import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/api_update_repository.dart';
import '../../features/settings/models/app_update.dart';
import '../app_version.dart';

// 强制升级门：两路准入判定，任一要求高于当前版本即封锁进壳。
//   1. 服务端 /system/info 的 minAppVersion——配合服务端大改动（如 API v2），
//      新服务端一声明，老 App 连上即被拦；
//   2. App 仓库 app-config.json 的 minVersion——不发服务端新版也能全局强制
//      （GitHub raw + jsDelivr 多镜像，见 repository）。
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
      final config = await repository.remoteAppConfig();
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
