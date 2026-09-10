import '../mi_direct_account.dart';
import 'mi_passport_result.dart';

/// 提交给表现层的认证结果不包含 serviceToken、ssecurity 或 passToken。
sealed class MiDirectLoginResult {
  const MiDirectLoginResult();
}

class MiDirectLoginAuthenticated extends MiDirectLoginResult {
  const MiDirectLoginAuthenticated(this.account);
  final MiDirectAccount account;
}

class MiDirectLoginChallenge extends MiDirectLoginResult {
  const MiDirectLoginChallenge(this.challenge);
  final MiPassportChallenge challenge;
}
