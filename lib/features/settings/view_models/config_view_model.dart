import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../shared/models/hmusic_notice.dart';
import '../data/api_settings_repository.dart';
import '../models/settings_section_states.dart';

final NotifierProvider<ConfigViewModel, ConfigFormState>
configViewModelProvider = NotifierProvider<ConfigViewModel, ConfigFormState>(
  ConfigViewModel.new,
);

class ConfigViewModel extends Notifier<ConfigFormState> {
  @override
  ConfigFormState build() => const ConfigFormState();

  Future<void> load() async {
    try {
      final config = await ref.read(settingsRepositoryProvider).getConfig();
      state = state.copyWith(config: config);
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: HMusicNotice.error(failure.message));
    }
  }

  // 表单值由 View 收集后整体提交；extraModels 是逗号/空格分隔的原始文本。
  Future<void> save({
    required String serverName,
    required String defaultQuality,
    required String searchStrategy,
    required String resolveStrategy,
    required String extraModelsText,
    required bool announceTracks,
  }) async {
    if (state.saving) return;
    state = state.copyWith(saving: true);
    try {
      final next = await ref
          .read(settingsRepositoryProvider)
          .patchConfig(
            serverName: serverName,
            defaultQuality: defaultQuality,
            searchStrategy: searchStrategy,
            resolveStrategy: resolveStrategy,
            extraPlayMusicModels: parseModels(extraModelsText),
            announceTracks: announceTracks,
          );
      state = state.copyWith(
        config: next,
        saving: false,
        notice: const HMusicNotice.success('配置已保存'),
      );
    } on ApiFailure catch (failure) {
      state = state.copyWith(
        saving: false,
        notice: HMusicNotice.error(failure.message),
      );
    }
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }
}

// 直连播放型号解析（对齐 web parseModels）：分隔 → 大写 → 只留字母数字 → 去重。
List<String> parseModels(String value) {
  final seen = <String>{};
  final pattern = RegExp(r'^[A-Z0-9]+$');
  return value
      .split(RegExp(r'[\s,，、]+'))
      .map((item) => item.trim().toUpperCase())
      .where((item) => item.isNotEmpty && pattern.hasMatch(item))
      .where(seen.add)
      .toList();
}
