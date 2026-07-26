import 'package:hmusic/features/settings/data/mi_account_repository.dart';
import 'package:hmusic/features/settings/models/mi_account.dart';

// 内存版小米账号仓库（更换账号链路测试共用）：status 可注入登录态，
// 扫码/登出返回固定值，其余按未实现抛错；calls 记录调用序列供断言。
class FakeMiAccountRepository implements MiAccountRepository {
  FakeMiAccountRepository({this.current = const MiStatus(loggedIn: false)});

  MiStatus current;
  final List<String> calls = <String>[];

  @override
  Future<MiStatus> status({bool verify = false}) async {
    calls.add(verify ? 'status:verify' : 'status');
    return current;
  }

  @override
  Future<MiQrSession> startQr() async {
    calls.add('qr:start');
    return MiQrSession(
      qrId: 'qr-1',
      loginUrl: 'https://account.xiaomi.com/qr/1',
      expiresAt: DateTime.now().millisecondsSinceEpoch + 60000,
    );
  }

  @override
  Future<MiQrPoll> pollQr(String qrId) async {
    calls.add('qr:poll:$qrId');
    return const MiQrPoll(status: MiQrPollStatus.pending);
  }

  @override
  Future<MiVerificationResult> startVerification({
    required String account,
    required String password,
    String? captchaCode,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<MiVerificationResult> confirmVerification({
    required String verificationId,
    required String code,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String?> resendVerification(String verificationId) async {
    throw UnimplementedError();
  }

  @override
  Future<MiVerificationResult> importSession({
    String? stsUrl,
    String? serviceToken,
    String? userId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {
    calls.add('logout');
    current = const MiStatus(loggedIn: false);
  }
}
