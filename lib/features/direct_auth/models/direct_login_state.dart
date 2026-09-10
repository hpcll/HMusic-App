import 'dart:typed_data';

import '../../../core/direct/auth/mi_passport_result.dart';
import '../../../core/direct/mi_direct_account.dart';

class DirectLoginState {
  const DirectLoginState({
    this.busy = false,
    this.account,
    this.challenge,
    this.captchaImage,
    this.errorMessage,
  });

  final bool busy;
  final MiDirectAccount? account;
  final MiPassportChallenge? challenge;
  final Uint8List? captchaImage;
  final String? errorMessage;
}
