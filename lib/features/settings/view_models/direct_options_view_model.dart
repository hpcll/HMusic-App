import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/playback/backend_request.dart';
import '../../../core/playback/playback_mode_controller.dart';
import '../data/direct_settings_repository.dart';
import '../models/direct_options.dart';
import 'settings_menu_view_model.dart';

final directOptionsViewModelProvider =
    NotifierProvider<DirectOptionsViewModel, DirectOptionsState>(
      DirectOptionsViewModel.new,
    );

class DirectOptionsViewModel extends Notifier<DirectOptionsState> {
  @override
  DirectOptionsState build() {
    ref.watch(playbackModeProvider);
    return const DirectOptionsState();
  }

  Future<void> load() async {
    final request = BackendRequest(ref);
    try {
      final options = await ref
          .read(directSettingsRepositoryProvider)
          .getOptions();
      if (request.current) state = DirectOptionsState(options: options);
    } catch (error) {
      if (request.current) {
        state = DirectOptionsState(message: _message(error), failed: true);
      }
    }
  }

  Future<void> save(DirectOptions options) async {
    if (state.saving) return;
    final request = BackendRequest(ref);
    state = DirectOptionsState(options: state.options, saving: true);
    try {
      await ref.read(directSettingsRepositoryProvider).saveOptions(options);
      if (request.current) {
        state = DirectOptionsState(options: options, message: '直连配置已保存');
        await ref.read(settingsMenuViewModelProvider.notifier).loadSummary();
      }
    } catch (error) {
      if (request.current) {
        state = DirectOptionsState(
          options: state.options,
          message: _message(error),
          failed: true,
        );
      }
    }
  }

  String _message(Object error) =>
      error is ApiFailure ? error.message : '无法读写本机配置，请重试';
}
