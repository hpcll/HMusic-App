enum AuthSubmissionStatus { idle, loadingStatus, submitting, authenticated }

class AuthViewState {
  const AuthViewState({
    this.status = AuthSubmissionStatus.idle,
    this.initialized = true,
    this.username,
    this.errorMessage,
  });

  final AuthSubmissionStatus status;
  final bool initialized;
  final String? username;
  final String? errorMessage;

  bool get isBusy =>
      status == AuthSubmissionStatus.loadingStatus ||
      status == AuthSubmissionStatus.submitting;

  bool get isAuthenticated => status == AuthSubmissionStatus.authenticated;

  AuthViewState copyWith({
    AuthSubmissionStatus? status,
    bool? initialized,
    String? username,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthViewState(
      status: status ?? this.status,
      initialized: initialized ?? this.initialized,
      username: username ?? this.username,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
