import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../data/api_settings_repository.dart';
import '../models/settings_section_states.dart';

final NotifierProvider<DiagViewModel, DiagState> diagViewModelProvider =
    NotifierProvider<DiagViewModel, DiagState>(DiagViewModel.new);

// 链路诊断：测试音 + TTS + 播放状态 3s 轮询。
// 轮询由子页 widget 的生命周期开关（进入 start、离开 stop），直接问 Server 不经 AudioHandler。
class DiagViewModel extends Notifier<DiagState> {
  Timer? _timer;

  @override
  DiagState build() {
    ref.onDispose(_stop);
    return const DiagState();
  }

  void startPolling() {
    if (_timer != null) return;
    unawaited(refreshState());
    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(refreshState()),
    );
  }

  void stopPolling() => _stop();

  Future<void> refreshState() async {
    try {
      final playback = await ref
          .read(settingsRepositoryProvider)
          .getPlaybackState();
      state = state.copyWith(playback: playback);
    } on ApiFailure {
      // 尽力而为：轮询失败保持上次状态，不打扰用户。
    }
  }

  Future<void> playTestTone() async {
    if (state.busyKind.isNotEmpty) return;
    state = state.copyWith(busyKind: 'tone');
    try {
      await ref.read(settingsRepositoryProvider).playTestTone();
      await refreshState();
      state = state.copyWith(notice: '测试音频已下发，注意听音箱');
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: failure.message);
    } finally {
      state = state.copyWith(busyKind: '');
    }
  }

  Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busyKind.isNotEmpty) return;
    state = state.copyWith(busyKind: 'tts');
    try {
      await ref.read(settingsRepositoryProvider).speak(trimmed);
      state = state.copyWith(notice: '播报已下发，注意听音箱');
    } on ApiFailure catch (failure) {
      state = state.copyWith(notice: failure.message);
    } finally {
      state = state.copyWith(busyKind: '');
    }
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }
}
