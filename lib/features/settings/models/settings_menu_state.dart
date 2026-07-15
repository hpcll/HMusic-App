import 'settings_section.dart';
import 'settings_summary.dart';

// 设置中心框架状态：当前子页 + 菜单摘要。
// section 为 null 表示窄屏菜单页；桌面双栏下 View 回退渲染第一项，不写回状态。
class SettingsMenuState {
  const SettingsMenuState({
    this.section,
    this.summary = const SettingsSummary(),
    this.summaryLoading = false,
  });

  final SettingsSection? section;
  final SettingsSummary summary;
  final bool summaryLoading;

  SettingsMenuState copyWith({
    SettingsSection? section,
    bool clearSection = false,
    SettingsSummary? summary,
    bool? summaryLoading,
  }) {
    return SettingsMenuState(
      section: clearSection ? null : (section ?? this.section),
      summary: summary ?? this.summary,
      summaryLoading: summaryLoading ?? this.summaryLoading,
    );
  }
}
