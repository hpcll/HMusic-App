import 'package:json_annotation/json_annotation.dart';

part 'mi_account.g.dart';

// 小米账号登录状态（GET /mi/status）。loggedIn 决定状态卡展示登录态/退出键；
// sessionExpired 区分「登录已过期」与「未登录」（旧 Server 无此字段，默认 false）。
@JsonSerializable(includeIfNull: false)
class MiStatus {
  const MiStatus({
    required this.loggedIn,
    this.sessionExpired = false,
    this.accountMasked,
  });

  factory MiStatus.fromJson(Map<String, Object?> json) =>
      _$MiStatusFromJson(json);

  @JsonKey(defaultValue: false)
  final bool loggedIn;

  @JsonKey(defaultValue: false)
  final bool sessionExpired;

  final String? accountMasked;

  Map<String, Object?> toJson() => _$MiStatusToJson(this);
}

// 扫码会话（POST /mi/qr/start）：loginUrl 本地渲染二维码，expiresAt 倒计时。
@JsonSerializable(includeIfNull: false)
class MiQrSession {
  const MiQrSession({
    required this.qrId,
    required this.loginUrl,
    required this.expiresAt,
  });

  factory MiQrSession.fromJson(Map<String, Object?> json) =>
      _$MiQrSessionFromJson(json);

  final String qrId;
  final String loginUrl;

  // 毫秒时间戳（对齐 web Date.now() 比较）。
  final int expiresAt;

  Map<String, Object?> toJson() => _$MiQrSessionToJson(this);
}

// 扫码轮询状态（GET /mi/qr/:id/status）。
enum MiQrPollStatus { pending, success, failed, expired, unknown }

@JsonSerializable(includeIfNull: false)
class MiQrPoll {
  const MiQrPoll({required this.status, this.message});

  factory MiQrPoll.fromJson(Map<String, Object?> json) =>
      _$MiQrPollFromJson(json);

  @JsonKey(unknownEnumValue: MiQrPollStatus.unknown)
  final MiQrPollStatus status;

  final String? message;

  Map<String, Object?> toJson() => _$MiQrPollToJson(this);
}

// 密码登录结果（POST /mi/verification/start）：要么直接登录成功，
// 要么返回短信挑战（verificationId + 掩码手机号 + 短信状态）。
@JsonSerializable(includeIfNull: false)
class MiVerificationResult {
  const MiVerificationResult({
    required this.loggedIn,
    this.deviceCount,
    this.verificationId,
    this.maskedPhone,
    this.smsStatus,
    this.expiresAt,
  });

  factory MiVerificationResult.fromJson(Map<String, Object?> json) =>
      _$MiVerificationResultFromJson(json);

  @JsonKey(defaultValue: false)
  final bool loggedIn;

  final int? deviceCount;

  // 需短信验证时非空。
  final String? verificationId;
  final String? maskedPhone;

  // recent(最近发过) / limited(限频) / 其他(已发送)。
  final String? smsStatus;
  final int? expiresAt;

  Map<String, Object?> toJson() => _$MiVerificationResultToJson(this);
}
