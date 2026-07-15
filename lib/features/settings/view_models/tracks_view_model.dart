import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../data/api_settings_repository.dart';
import '../models/server_config.dart';
import '../models/settings_section_states.dart';

final NotifierProvider<TracksViewModel, TracksState> tracksViewModelProvider =
    NotifierProvider<TracksViewModel, TracksState>(TracksViewModel.new);

// 手工曲目：读走 /config，改走 PATCH manualTracks 全量替换（对齐 web TracksSection）。
class TracksViewModel extends Notifier<TracksState> {
  @override
  TracksState build() => const TracksState();

  Future<void> load() async {
    try {
      final config = await ref.read(settingsRepositoryProvider).getConfig();
      state = state.copyWith(tracks: config.manualTracks, loaded: true);
    } on ApiFailure catch (failure) {
      state = state.copyWith(loaded: true, notice: failure.message);
    }
  }

  // 返回是否成功，View 据此清空表单。
  Future<bool> add({
    required String title,
    required String artist,
    required String url,
  }) async {
    final t = title.trim();
    final u = url.trim();
    if (t.isEmpty || u.isEmpty) {
      state = state.copyWith(notice: '标题和音频 URL 不能为空');
      return false;
    }
    if (state.busy) return false;
    state = state.copyWith(busy: true);
    final next = <ManualTrack>[
      ...state.tracks,
      ManualTrack(
        title: t,
        artist: artist.trim().isEmpty ? null : artist.trim(),
        url: u,
      ),
    ];
    final ok = await _save(next, '曲目已添加');
    return ok;
  }

  Future<void> removeAt(int index) async {
    if (state.busy || index < 0 || index >= state.tracks.length) return;
    state = state.copyWith(busy: true);
    final next = <ManualTrack>[...state.tracks]..removeAt(index);
    await _save(next, '曲目已删除');
  }

  Future<bool> _save(List<ManualTrack> next, String successNotice) async {
    try {
      final config = await ref
          .read(settingsRepositoryProvider)
          .patchConfig(manualTracks: next);
      state = state.copyWith(
        tracks: config.manualTracks,
        busy: false,
        notice: successNotice,
      );
      return true;
    } on ApiFailure catch (failure) {
      state = state.copyWith(busy: false, notice: failure.message);
      return false;
    }
  }

  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }
}
