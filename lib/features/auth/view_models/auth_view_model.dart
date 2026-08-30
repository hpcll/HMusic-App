import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/session/session_providers.dart';
import '../data/api_auth_repository.dart';
import '../models/auth_view_state.dart';

final NotifierProvider<AuthViewModel, AuthViewState> authViewModelProvider =
    NotifierProvider<AuthViewModel, AuthViewState>(AuthViewModel.new);

class AuthViewModel extends Notifier<AuthViewState> {
  @override
  AuthViewState build() => const AuthViewState();

  Future<void> loadStatus() async {
    if (state.isBusy) return;
    state = state.copyWith(
      status: AuthSubmissionStatus.loadingStatus,
      clearError: true,
    );
    try {
      final result = await ref.read(authRepositoryProvider).status();
      state = state.copyWith(
        status: result.authenticated
            ? AuthSubmissionStatus.authenticated
            : AuthSubmissionStatus.idle,
        initialized: result.initialized,
        checked: true,
        username: result.user?.username,
        clearError: true,
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        status: AuthSubmissionStatus.idle,
        // 问不到就按"要登录"处理：把表单放出来让用户能重试，总好过停在开场画面。
        checked: true,
        errorMessage: failure.message,
      );
    } catch (error) {
      // 同 submit：状态探测卡住会让整页停在加载态，宁可报错也不能不动。
      debugPrint('[AuthViewModel] 读取登录状态出现意外失败：$error');
      state = state.copyWith(
        status: AuthSubmissionStatus.idle,
        checked: true,
        errorMessage: '无法获取登录状态：$error',
      );
    }
  }

  Future<bool> submit({
    required String username,
    required String password,
  }) async {
    if (state.isBusy) return false;
    if (username.trim().length < 3) return _validationError('用户名至少 3 个字符');
    if (password.length < 8) return _validationError('密码至少 8 个字符');

    state = state.copyWith(
      status: AuthSubmissionStatus.submitting,
      clearError: true,
    );
    try {
      final repository = ref.read(authRepositoryProvider);
      final session = state.initialized
          ? await repository.login(
              username: username.trim(),
              password: password,
            )
          : await repository.setup(
              username: username.trim(),
              password: password,
            );
      state = state.copyWith(
        status: AuthSubmissionStatus.authenticated,
        initialized: true,
        username: session.user.username,
        clearError: true,
      );
      // 登录/创建管理员成功后复位 401 单飞，避免上一会话的失效标志把刚登录的用户立即踢回登录页。
      ref.read(sessionControllerProvider).markValid();
      return true;
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        status: AuthSubmissionStatus.idle,
        errorMessage: failure.message,
      );
      return false;
    } catch (error) {
      // 兜底：非 ApiFailure 的意外（平台存储通道失效、响应结构不符…）也必须把
      // 提交态放下来。否则按钮永久停在「处理中…」，用户既看不到原因也无法重试——
      // 曾有机型的钥匙串写入异常从这里逃出去，正是这个症状。
      debugPrint('[AuthViewModel] 登录出现意外失败：$error');
      state = state.copyWith(
        status: AuthSubmissionStatus.idle,
        errorMessage: '登录失败：$error',
      );
      return false;
    }
  }

  bool _validationError(String message) {
    state = state.copyWith(errorMessage: message);
    return false;
  }
}
