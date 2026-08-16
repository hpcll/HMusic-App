import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../data/api_mi_account_repository.dart';
import '../models/mi_account.dart';
import '../models/mi_account_state.dart';
import 'mi_session_watch_view_model.dart';
import 'settings_menu_view_model.dart';

final NotifierProvider<MiAccountViewModel, MiAccountState>
miAccountViewModelProvider =
    NotifierProvider<MiAccountViewModel, MiAccountState>(
      MiAccountViewModel.new,
    );

// 小米账号（对齐 web MiAccountSection）：扫码 / 账号密码+短信 / 导入会话三通道。
// 扫码为主推：start 拿 loginUrl 交 View 本地渲染二维码，2s 轮询状态 + 1s 倒计时。
class MiAccountViewModel extends Notifier<MiAccountState> {
  Timer? _pollTimer;
  Timer? _tickTimer;

  @override
  MiAccountState build() {
    ref.onDispose(_stopQrTimers);
    return const MiAccountState();
  }

  // 登录/退出这类改了服务端状态的动作后，重拉设置页左栏摘要——宽屏布局下
  // 摘要只在进页时加载一次，不刷会一直挂着「未登录」旧快照。
  // 尽力而为：摘要刷不动（依赖未挂载/网络抖动）不影响主流程。
  void _refreshMenuSummary() {
    try {
      unawaited(
        ref
            .read(settingsMenuViewModelProvider.notifier)
            .loadSummary()
            .catchError((Object _) {}),
      );
    } catch (_) {}
  }

  Future<void> loadStatus() async {
    try {
      final status = await ref.read(miAccountRepositoryProvider).status();
      // 登录态掉线（主动退出/会话过期/他端登出）时清干净三通道：登录面板
      // 重新展开必须从新鲜扫码页开始，不残留上一轮「登录成功」等旧态。
      final droppedOut = state.loggedIn && !status.loggedIn;
      // 每次确认状态都收起「更换账号」：登录成功/退出后回到默认视图。
      state = state.copyWith(status: status, changingAccount: false);
      if (droppedOut) _resetChannels(changingAccount: false);
      // 同步全局过期横幅：重新登录/退出后立即消退，不等下一轮检测。
      ref.read(miSessionWatchProvider.notifier).applyStatus(status);
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    }
  }

  // 已登录时翻转「更换账号」面板。Server 是单账号模型：新登录会替换当前账号。
  // 开合都复位三通道：重开从干净扫码页开始，收起同时停掉遗留轮询。
  void toggleChangeAccount() {
    _resetChannels(changingAccount: !state.changingAccount);
  }

  void _resetChannels({required bool changingAccount}) {
    _stopQrTimers();
    state = state.copyWith(
      changingAccount: changingAccount,
      tab: MiTab.qr,
      qrStage: MiQrStage.idle,
      qrRemain: '',
      clearQrSession: true,
      clearQrMessage: true,
      clearChallenge: true,
    );
  }

  void switchTab(MiTab tab) {
    if (state.tab == tab) return;
    state = state.copyWith(tab: tab);
  }

  // ===== 扫码通道 =====
  Future<void> startQr() async {
    _stopQrTimers();
    state = state.copyWith(
      qrStage: MiQrStage.loading,
      clearQrMessage: true,
      clearQrSession: true,
    );
    try {
      final session = await ref.read(miAccountRepositoryProvider).startQr();
      state = state.copyWith(qrStage: MiQrStage.pending, qrSession: session);
      _tick();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(_pollQr()),
      );
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        qrStage: MiQrStage.failed,
        qrMessage: failure.message,
      );
    }
  }

  Future<void> _pollQr() async {
    final session = state.qrSession;
    if (session == null) return;
    try {
      final poll = await ref
          .read(miAccountRepositoryProvider)
          .pollQr(session.qrId);
      switch (poll.status) {
        case MiQrPollStatus.success:
          _stopQrTimers();
          state = state.copyWith(qrStage: MiQrStage.success);
          await loadStatus();
          _refreshMenuSummary();
          state = state.copyWith(notice: const HMusicNotice.success('小米账号已登录'));
        case MiQrPollStatus.failed:
          _stopQrTimers();
          state = state.copyWith(
            qrStage: MiQrStage.failed,
            qrMessage: poll.message ?? '',
          );
        case MiQrPollStatus.expired:
          _stopQrTimers();
          state = state.copyWith(qrStage: MiQrStage.expired);
        case MiQrPollStatus.pending:
        case MiQrPollStatus.unknown:
          break; // 继续等待下一轮
      }
    } on ApiFailure {
      // 单次轮询失败忽略，下一轮继续（对齐 web）。
    }
  }

  // 刷新倒计时 mm:ss；过期则停表并转 expired。
  void _tick() {
    final session = state.qrSession;
    if (session == null) return;
    final leftMs = session.expiresAt - DateTime.now().millisecondsSinceEpoch;
    if (leftMs <= 0) {
      _stopQrTimers();
      state = state.copyWith(qrStage: MiQrStage.expired, qrRemain: '00:00');
      return;
    }
    final left = leftMs ~/ 1000;
    final m = (left ~/ 60).toString().padLeft(2, '0');
    final s = (left % 60).toString().padLeft(2, '0');
    state = state.copyWith(qrRemain: '$m:$s');
  }

  // ===== 密码 + 短信通道 =====
  Future<void> loginPassword({
    required String account,
    required String password,
    required String captcha,
  }) async {
    if (account.trim().isEmpty || password.isEmpty) {
      state = state.copyWith(notice: const HMusicNotice.error('请填写小米账号和密码'));
      return;
    }
    if (state.busy) return;
    state = state.copyWith(busy: true);
    try {
      final result = await ref
          .read(miAccountRepositoryProvider)
          .startVerification(
            account: account.trim(),
            password: password,
            captchaCode: captcha.trim().isEmpty ? null : captcha.trim(),
          );
      if (result.loggedIn) {
        state = state.copyWith(busy: false, clearChallenge: true);
        await loadStatus();
        _refreshMenuSummary();
        state = state.copyWith(
          notice: HMusicNotice.success(
            '登录成功，发现 ${result.deviceCount ?? 0} 台设备',
          ),
        );
      } else {
        state = state.copyWith(
          busy: false,
          challenge: result,
          notice: HMusicNotice(_smsHint(result.smsStatus)),
        );
      }
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        busy: false,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  Future<void> confirmSms(String code) async {
    final challenge = state.challenge;
    if (challenge?.verificationId == null || code.trim().isEmpty) return;
    if (state.busy) return;
    state = state.copyWith(busy: true);
    try {
      final result = await ref
          .read(miAccountRepositoryProvider)
          .confirmVerification(
            verificationId: challenge!.verificationId!,
            code: code.trim(),
          );
      state = state.copyWith(busy: false, clearChallenge: true);
      await loadStatus();
      _refreshMenuSummary();
      state = state.copyWith(
        notice: HMusicNotice.success('登录成功，发现 ${result.deviceCount ?? 0} 台设备'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        busy: false,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  Future<void> resendSms() async {
    final challenge = state.challenge;
    if (challenge?.verificationId == null) return;
    try {
      final smsStatus = await ref
          .read(miAccountRepositoryProvider)
          .resendVerification(challenge!.verificationId!);
      state = state.copyWith(notice: HMusicNotice(_smsHint(smsStatus)));
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    }
  }

  // 放弃短信挑战，回到密码输入。
  void cancelChallenge() {
    state = state.copyWith(clearChallenge: true);
  }

  String _smsHint(String? status) {
    return switch (status) {
      'recent' => '短信最近已发过，直接填收到的验证码',
      'limited' => '短信被限频，建议改用扫码登录',
      _ => '验证码已发送',
    };
  }

  // ===== 导入会话通道 =====
  Future<void> importSession({
    required String stsUrl,
    required String serviceToken,
    required String userId,
  }) async {
    final url = stsUrl.trim();
    final token = serviceToken.trim();
    final uid = userId.trim();
    if (url.isEmpty && !(token.isNotEmpty && uid.isNotEmpty)) {
      state = state.copyWith(
        notice: const HMusicNotice.error('请填写 STS 地址，或 serviceToken + userId'),
      );
      return;
    }
    if (state.busy) return;
    state = state.copyWith(busy: true);
    try {
      final result = await ref
          .read(miAccountRepositoryProvider)
          .importSession(
            stsUrl: url.isEmpty ? null : url,
            serviceToken: token.isEmpty ? null : token,
            userId: uid.isEmpty ? null : uid,
          );
      state = state.copyWith(busy: false);
      await loadStatus();
      _refreshMenuSummary();
      state = state.copyWith(
        notice: HMusicNotice.success('导入成功，发现 ${result.deviceCount ?? 0} 台设备'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        busy: false,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  Future<void> logout() async {
    try {
      await ref.read(miAccountRepositoryProvider).logout();
      await loadStatus();
      _refreshMenuSummary();
      state = state.copyWith(notice: const HMusicNotice.success('已退出小米账号'));
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    }
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }

  void _stopQrTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _tickTimer?.cancel();
    _tickTimer = null;
  }
}
