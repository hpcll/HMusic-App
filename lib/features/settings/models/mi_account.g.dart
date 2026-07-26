// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mi_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MiStatus _$MiStatusFromJson(Map<String, dynamic> json) => MiStatus(
  loggedIn: json['loggedIn'] as bool? ?? false,
  sessionExpired: json['sessionExpired'] as bool? ?? false,
  accountMasked: json['accountMasked'] as String?,
);

Map<String, dynamic> _$MiStatusToJson(MiStatus instance) => <String, dynamic>{
  'loggedIn': instance.loggedIn,
  'sessionExpired': instance.sessionExpired,
  'accountMasked': ?instance.accountMasked,
};

MiQrSession _$MiQrSessionFromJson(Map<String, dynamic> json) => MiQrSession(
  qrId: json['qrId'] as String,
  loginUrl: json['loginUrl'] as String,
  expiresAt: (json['expiresAt'] as num).toInt(),
);

Map<String, dynamic> _$MiQrSessionToJson(MiQrSession instance) =>
    <String, dynamic>{
      'qrId': instance.qrId,
      'loginUrl': instance.loginUrl,
      'expiresAt': instance.expiresAt,
    };

MiQrPoll _$MiQrPollFromJson(Map<String, dynamic> json) => MiQrPoll(
  status: $enumDecode(
    _$MiQrPollStatusEnumMap,
    json['status'],
    unknownValue: MiQrPollStatus.unknown,
  ),
  message: json['message'] as String?,
);

Map<String, dynamic> _$MiQrPollToJson(MiQrPoll instance) => <String, dynamic>{
  'status': _$MiQrPollStatusEnumMap[instance.status]!,
  'message': ?instance.message,
};

const _$MiQrPollStatusEnumMap = {
  MiQrPollStatus.pending: 'pending',
  MiQrPollStatus.success: 'success',
  MiQrPollStatus.failed: 'failed',
  MiQrPollStatus.expired: 'expired',
  MiQrPollStatus.unknown: 'unknown',
};

MiVerificationResult _$MiVerificationResultFromJson(
  Map<String, dynamic> json,
) => MiVerificationResult(
  loggedIn: json['loggedIn'] as bool? ?? false,
  deviceCount: (json['deviceCount'] as num?)?.toInt(),
  verificationId: json['verificationId'] as String?,
  maskedPhone: json['maskedPhone'] as String?,
  smsStatus: json['smsStatus'] as String?,
  expiresAt: (json['expiresAt'] as num?)?.toInt(),
);

Map<String, dynamic> _$MiVerificationResultToJson(
  MiVerificationResult instance,
) => <String, dynamic>{
  'loggedIn': instance.loggedIn,
  'deviceCount': ?instance.deviceCount,
  'verificationId': ?instance.verificationId,
  'maskedPhone': ?instance.maskedPhone,
  'smsStatus': ?instance.smsStatus,
  'expiresAt': ?instance.expiresAt,
};
