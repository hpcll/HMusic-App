import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../models/mi_account.dart';
import 'mi_account_repository.dart';

final Provider<MiAccountRepository> miAccountRepositoryProvider =
    Provider<MiAccountRepository>((ref) {
      return ApiMiAccountRepository(apiClient: ref.watch(apiClientProvider));
    });

class ApiMiAccountRepository implements MiAccountRepository {
  const ApiMiAccountRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<MiStatus> status() async {
    return MiStatus.fromJson(await _apiClient.getMap('/mi/status'));
  }

  @override
  Future<MiQrSession> startQr() async {
    return MiQrSession.fromJson(await _apiClient.postMap('/mi/qr/start'));
  }

  @override
  Future<MiQrPoll> pollQr(String qrId) async {
    return MiQrPoll.fromJson(
      await _apiClient.getMap('/mi/qr/${Uri.encodeComponent(qrId)}/status'),
    );
  }

  @override
  Future<MiVerificationResult> startVerification({
    required String account,
    required String password,
    String? captchaCode,
  }) async {
    return MiVerificationResult.fromJson(
      await _apiClient.postMap(
        '/mi/verification/start',
        body: <String, Object?>{
          'account': account,
          'password': password,
          if (captchaCode != null && captchaCode.isNotEmpty)
            'captchaCode': captchaCode,
        },
      ),
    );
  }

  @override
  Future<MiVerificationResult> confirmVerification({
    required String verificationId,
    required String code,
  }) async {
    return MiVerificationResult.fromJson(
      await _apiClient.postMap(
        '/mi/verification/${Uri.encodeComponent(verificationId)}/confirm',
        body: <String, Object?>{'code': code},
      ),
    );
  }

  @override
  Future<String?> resendVerification(String verificationId) async {
    final payload = await _apiClient.postMap(
      '/mi/verification/${Uri.encodeComponent(verificationId)}/resend',
    );
    return payload['smsStatus'] as String?;
  }

  @override
  Future<MiVerificationResult> importSession({
    String? stsUrl,
    String? serviceToken,
    String? userId,
  }) async {
    // STS 地址优先；否则用 serviceToken + userId。web 侧 account 固定填 "imported"。
    final webCredentials = stsUrl != null && stsUrl.isNotEmpty
        ? <String, Object?>{'stsUrl': stsUrl}
        : <String, Object?>{'serviceToken': serviceToken, 'userId': userId};
    return MiVerificationResult.fromJson(
      await _apiClient.postMap(
        '/mi/session/import',
        body: <String, Object?>{
          'account': 'imported',
          'webCredentials': webCredentials,
        },
      ),
    );
  }

  @override
  Future<void> logout() async {
    await _apiClient.postMap('/mi/logout');
  }
}
