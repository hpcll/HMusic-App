import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/infrastructure_providers.dart';
import 'upgrade_gate.dart';

// 把 ApiClient 的「服务端按版本门槛拒绝服务」接到强升门：任何业务请求撞上
// 403 APP_VERSION_TOO_OLD 就立即封锁进壳，不等门控下一轮自检。
//
// 在 app 根激活（同 sessionGuard）而非由 apiClientProvider 拉起：
// upgradeGate 依赖 updateRepository → apiClient，反向 watch 会成环。
final Provider<void> appVersionGuardProvider = Provider<void>((ref) {
  ref
      .watch(apiClientProvider)
      .registerVersionRejectedHandler(
        (minAppVersion) => ref
            .read(upgradeGateProvider.notifier)
            .rejectedByServer(minAppVersion),
      );
});
