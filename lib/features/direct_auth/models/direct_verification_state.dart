import '../../../core/direct/auth/mi_web_verifier.dart';

class DirectVerificationState {
  const DirectVerificationState({
    this.loading = true,
    this.closed = false,
    this.result,
    this.errorMessage,
  });
  final bool loading;
  final bool closed;
  final MiWebAuthResult? result;
  final String? errorMessage;
}
