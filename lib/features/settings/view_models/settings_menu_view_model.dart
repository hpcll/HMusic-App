import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_settings_repository.dart';
import '../models/settings_menu_state.dart';
import '../models/settings_section.dart';

final NotifierProvider<SettingsMenuViewModel, SettingsMenuState>
settingsMenuViewModelProvider =
    NotifierProvider<SettingsMenuViewModel, SettingsMenuState>(
      SettingsMenuViewModel.new,
    );

// 设置中心框架：子页导航 + 菜单实时摘要（并发五路拉取，见 repository）。
class SettingsMenuViewModel extends Notifier<SettingsMenuState> {
  @override
  SettingsMenuState build() => const SettingsMenuState();

  Future<void> loadSummary() async {
    state = state.copyWith(summaryLoading: true);
    final summary = await ref.read(settingsRepositoryProvider).loadSummary();
    state = state.copyWith(summary: summary, summaryLoading: false);
  }

  void open(SettingsSection section) {
    state = state.copyWith(section: section);
  }

  // 窄屏返回菜单页并刷新摘要（子页里改过的状态要反映到摘要上）。
  Future<void> back() async {
    state = state.copyWith(clearSection: true);
    await loadSummary();
  }
}
