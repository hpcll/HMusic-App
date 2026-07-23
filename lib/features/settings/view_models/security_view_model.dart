import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../../../core/session/session_providers.dart';
import '../../../shared/models/hmusic_notice.dart';
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
      state = state.copyWith(notice: const HMusicNotice.error('新密码至少 8 个字符'));
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
      state = state.copyWith(
        changing: false,
        notice: const HMusicNotice.success('密码已修改'),
      );
      return true;
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        changing: false,
        notice: HMusicNotice.error(failure.message),
      );
      return false;
    }
  }

  // 删除账户：服务端物理清库成功后，清 token + 会话失效，由 router redirect
  // 统一回登录/setup。返回是否成功（View 据此收尾）。
  Future<bool> deleteAccount({required String password}) async {
    if (state.deleting) return false;
    state = state.copyWith(deleting: true);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .deleteAccount(password: password);
      await ref.read(tokenStoreProvider).clear();
      ref.read(sessionControllerProvider).invalidate();
      // 不复位 deleting：本页即将被 redirect 卸载，避免删后一瞬按钮回弹可点。
      return true;
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        deleting: false,
        notice: HMusicNotice.error(failure.message),
      );
      return false;
    }
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }
}
