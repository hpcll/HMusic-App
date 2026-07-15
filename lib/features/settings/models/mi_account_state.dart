import 'mi_account.dart';

// 小米账号子页的三个登录通道。
enum MiTab { qr, password, importSession }

// 扫码阶段：idle 未开始 / loading 生成中 / pending 等待扫码 /
// success 成功 / failed 失败 / expired 过期。
enum MiQrStage { idle, loading, pending, success, failed, expired }

// 小米账号子页状态（对齐 web MiAccountSection）。状态卡 + 三通道各自子状态聚在一处，
// 互不引用但同属一页，集中一个 Notifier 管理更顺。
class MiAccountState {
  const MiAccountState({
    this.status,
    this.tab = MiTab.qr,
    this.qrStage = MiQrStage.idle,
    this.qrSession,
    this.qrMessage,
    this.qrRemain = '',
    this.busy = false,
    this.challenge,
    this.notice,
  });

  // ── 状态卡 ──
  final MiStatus? status;
  final MiTab tab;

  // ── 扫码通道 ──
  final MiQrStage qrStage;
  final MiQrSession? qrSession;

  // 失败/过期时的可读原因。
  final String? qrMessage;

  // 倒计时 mm:ss（每秒刷新）。
  final String qrRemain;

  // ── 密码 + 短信通道 ──
  // 密码登录 / 短信确认 / 导入进行中共用。
  final bool busy;

  // 非空表示进入短信挑战阶段。
  final MiVerificationResult? challenge;

  final String? notice;

  bool get loggedIn => status?.loggedIn ?? false;

  MiAccountState copyWith({
    MiStatus? status,
    MiTab? tab,
    MiQrStage? qrStage,
    MiQrSession? qrSession,
    String? qrMessage,
    String? qrRemain,
    bool? busy,
    MiVerificationResult? challenge,
    String? notice,
    bool clearQrSession = false,
    bool clearQrMessage = false,
    bool clearChallenge = false,
    bool clearNotice = false,
  }) {
    return MiAccountState(
      status: status ?? this.status,
      tab: tab ?? this.tab,
      qrStage: qrStage ?? this.qrStage,
      qrSession: clearQrSession ? null : (qrSession ?? this.qrSession),
      qrMessage: clearQrMessage ? null : (qrMessage ?? this.qrMessage),
      qrRemain: qrRemain ?? this.qrRemain,
      busy: busy ?? this.busy,
      challenge: clearChallenge ? null : (challenge ?? this.challenge),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}
