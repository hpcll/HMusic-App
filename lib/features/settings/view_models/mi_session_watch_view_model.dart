import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../data/api_mi_account_repository.dart';
import '../models/mi_account.dart';

final NotifierProvider<MiSessionWatchViewModel, MiSessionWatchState>
miSessionWatchProvider =
    NotifierProvider<MiSessionWatchViewModel, MiSessionWatchState>(
      MiSessionWatchViewModel.new,
    );

// 小米会话过期的全局横幅状态：过期是持续状态且需要行动入口，一次性 toast
// 兜不住（IgnorePointer 点不了也留不住），由常驻壳层横幅承担。
class MiSessionWatchState {
  const MiSessionWatchState({
    this.expired = false,
    this.accountMasked,
    this.dismissed = false,
  });

  final bool expired;
  final String? accountMasked;

  // 本次运行内手动关闭过横幅；过期状态解除后自动复位，下次再过期仍会提示。
  final bool dismissed;

  bool get showBanner => expired && !dismissed;
}

// 检测时机：壳层挂载（冷启动）与回前台各查一次 verify=1（服务端限频真校验），
// 播放链路报错后做一次快照回读（ubus 401 已由 Server 当场落库）。检测失败
// 保持上次已知状态：横幅只在确证过期时打扰，不拿网络抖动吓人。
class MiSessionWatchViewModel extends Notifier<MiSessionWatchState> {
  DateTime? _lastVerifyAt;
  DateTime? _lastQuickAt;

  static const Duration _verifyInterval = Duration(minutes: 5);
  static const Duration _quickInterval = Duration(seconds: 30);

  @override
  MiSessionWatchState build() => const MiSessionWatchState();

  // 冷启动 / 回前台：请求服务端真校验（与服务端 5min 限频同拍）。
  Future<void> check() async {
    if (!_due(_lastVerifyAt, _verifyInterval)) return;
    _lastVerifyAt = DateTime.now();
    await _refresh(verify: true);
  }

  // 播放失败后的快照回读：Server 在 401 时已落库，纯读不再打小米。
  Future<void> refreshQuick() async {
    if (!_due(_lastQuickAt, _quickInterval)) return;
    _lastQuickAt = DateTime.now();
    await _refresh(verify: false);
  }

  // 设置页每次 loadStatus 的结果同步进来：登录/退出后横幅即时消退。
  void applyStatus(MiStatus status) {
    final expired = status.sessionExpired && !status.loggedIn;
    state = MiSessionWatchState(
      expired: expired,
      accountMasked: status.accountMasked,
      dismissed: expired && state.dismissed,
    );
  }

  void dismiss() {
    state = MiSessionWatchState(
      expired: state.expired,
      accountMasked: state.accountMasked,
      dismissed: true,
    );
  }

  Future<void> _refresh({required bool verify}) async {
    try {
      final status = await ref
          .read(miAccountRepositoryProvider)
          .status(verify: verify);
      applyStatus(status);
    } on ApiFailure {
      // 静默：网络失败既不弹横幅也不清横幅。
    }
  }

  bool _due(DateTime? last, Duration interval) {
    return last == null || DateTime.now().difference(last) >= interval;
  }
}
