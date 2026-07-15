import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../data/api_settings_repository.dart';
import '../models/settings_section_states.dart';

final NotifierProvider<SecurityViewModel, SecurityState>
securityViewModelProvider = NotifierProvider<SecurityViewModel, SecurityState>(
  SecurityViewModel.new,
);

class SecurityViewModel extends Notifier<SecurityState> {
  @override
  SecurityState build() => const SecurityState();

  // 返回是否成功，View 据此清空表单；新 token 由 repository 落盘免重登。
  Future<bool> change({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (state.changing) return false;
    if (newPassword.length < 8) {
      state = state.copyWith(notice: '新密码至少 8 个字符');
      return false;
    }
    state = state.copyWith(changing: true);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      state = state.copyWith(changing: false, notice: '密码已修改');
      return true;
    } on ApiFailure catch (failure) {
      state = state.copyWith(changing: false, notice: failure.message);
      return false;
    }
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }
}
