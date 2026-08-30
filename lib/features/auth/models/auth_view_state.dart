enum AuthSubmissionStatus { idle, loadingStatus, submitting, authenticated }

class AuthViewState {
  const AuthViewState({
    this.status = AuthSubmissionStatus.idle,
    this.initialized = true,
    this.checked = false,
    this.username,
    this.errorMessage,
  });

  final AuthSubmissionStatus status;
  final bool initialized;

  // 是否已经问过服务端"当前登录状态"。默认 false，页面据此决定要不要渲染登录
  // 表单——问都还没问就把用户名密码框摆出来，冷启动接续成功的用户会先被闪一下
  // 登录页再跳首页（status 初值是 idle，不是 loadingStatus，所以首帧就渲染了表单）。
  // 不能靠把 status 初值改成 loadingStatus 解决：isBusy 会随之为真，
  // loadStatus() 开头那道 isBusy 守卫会把第一次探测直接挡掉。
  final bool checked;

  final String? username;
  final String? errorMessage;

  bool get isBusy =>
      status == AuthSubmissionStatus.loadingStatus ||
      status == AuthSubmissionStatus.submitting;

  bool get isAuthenticated => status == AuthSubmissionStatus.authenticated;

  // 可以把登录表单摆出来了：状态问过了，而且确实没登录。
  bool get needsSignIn => checked && !isAuthenticated;

  AuthViewState copyWith({
    AuthSubmissionStatus? status,
    bool? initialized,
    bool? checked,
    String? username,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthViewState(
      status: status ?? this.status,
      initialized: initialized ?? this.initialized,
      checked: checked ?? this.checked,
      username: username ?? this.username,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
