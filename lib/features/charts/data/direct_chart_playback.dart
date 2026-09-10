import 'dart:async';

import '../../../core/audio/models/hmusic_playback_state.dart';
import '../../../core/direct/playback/direct_playback_repository.dart';
import '../../../core/models/hmusic_track.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/queue/direct_queue_repository.dart';
import '../../search/data/search_repository.dart';
import '../models/chart.dart';

class DirectChartPlayback {
  DirectChartPlayback(this._playback, this._queue, this._search);
  final DirectPlaybackRepository _playback;
  final DirectQueueRepository _queue;
  final SearchRepository _search;
  int _sequence = 0;
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _sequence++;
  }

  Future<HMusicPlaybackState> play(ChartDetail detail, int startIndex) async {
    final sequence = ++_sequence;
    var revision = _queue.revision;
    bool current() =>
        !_disposed && sequence == _sequence && revision == _queue.revision;
    void requireCurrent() {
      if (!current()) throw _cancelled;
    }

    final entries = detail.entries;
    if (startIndex < 0 || startIndex >= entries.length) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        message: '榜单为空或播放位置已失效',
      );
    }
    requireCurrent();
    if (entries.every((entry) => entry.track != null)) {
      return _playback.playQueue(
        entries.map((entry) => entry.track!).toList(),
        startIndex: startIndex,
        isCurrent: current,
        onQueueReplaced: (value) => revision = value,
      );
    }

    for (var index = startIndex; index < entries.length; index++) {
      final first = await _match(entries[index]);
      requireCurrent();
      if (first == null) continue;
      final state = await _playback.playQueue(
        [first],
        isCurrent: current,
        onQueueReplaced: (value) => revision = value,
      );
      requireCurrent();
      // 首曲开播后继续按榜单顺序匹配；每次落盘都再次核对所属队列。
      unawaited(_append(entries.skip(index + 1), revision, current));
      return state;
    }
    throw const ApiFailure(
      kind: ApiFailureKind.invalidResponse,
      message: '榜单曲目暂未匹配到可播放音源',
    );
  }

  Future<HMusicTrack?> _match(ChartEntry entry) async {
    if (entry.track != null) return entry.track;
    try {
      return (await _search.search(
        '${entry.title} ${entry.artist}'.trim(),
      )).tracks.firstOrNull;
    } on Exception {
      return null;
    }
  }

  Future<void> _append(
    Iterable<ChartEntry> entries,
    int revision,
    bool Function() current,
  ) async {
    try {
      for (final entry in entries) {
        if (!current()) return;
        final track = await _match(entry);
        if (!current()) return;
        if (track == null) continue;
        if (!await _queue.appendIfCurrent(
          track,
          revision: revision,
          isCurrent: current,
        )) {
          return;
        }
      }
    } on Exception {
      // 后续匹配或本地存储失败不打断已经开始的首曲。
    }
  }

  static const _cancelled = ApiFailure(
    kind: ApiFailureKind.invalidConfiguration,
    code: 'DIRECT_CHART_PLAY_CANCELLED',
    message: '榜单播放已被新的队列操作取消',
  );
}
