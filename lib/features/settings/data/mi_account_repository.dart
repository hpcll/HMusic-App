import '../models/mi_account.dart';

// 小米账号仓库（对齐 web MiAccountSection）：状态 + 三通道登录。
// 扫码：start 拿 loginUrl 本地渲染，poll 每 2s 查；密码：start 可能直登或要短信，
// confirm/resend 走短信挑战；导入：STS 地址或 serviceToken+userId 兜底。
abstract interface class MiAccountRepository {
  // verify=true 请求服务端做限频真校验（GET /mi/status?verify=1）：
  // 冷启/回前台的过期检测用；设置页普通刷新保持快照读取。
  Future<MiStatus> status({bool verify});

  // ===== 扫码通道 =====
  Future<MiQrSession> startQr();

  Future<MiQrPoll> pollQr(String qrId);

  // ===== 密码 + 短信通道 =====
  // captchaCode 仅在服务端提示需要时传。返回可能直登成功或带短信挑战。
  Future<MiVerificationResult> startVerification({
    required String account,
    required String password,
    String? captchaCode,
  });

  // 短信验证码确认（code 4-12 位）。
  Future<MiVerificationResult> confirmVerification({
    required String verificationId,
    required String code,
  });

  // 重发短信，返回新的 smsStatus。
  Future<String?> resendVerification(String verificationId);

  // ===== 导入会话通道 =====
  // stsUrl 与 (serviceToken+userId) 二选一，调用方保证至少一组非空。
  Future<MiVerificationResult> importSession({
    String? stsUrl,
    String? serviceToken,
    String? userId,
  });

  Future<void> logout();
}
