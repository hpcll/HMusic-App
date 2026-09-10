import 'dart:math';

import '../audio/models/hmusic_playback_state.dart';
import '../direct/storage/direct_local_store.dart';
import '../models/hmusic_track.dart';
import '../network/api_failure.dart';
import 'models/hmusic_queue.dart';
import 'queue_repository.dart';

class DirectQueueRepository implements QueueRepository {
  DirectQueueRepository(this._store);

  final DirectLocalStore _store;
  int _revision = 0;
  int get revision => _revision;

  void cancelPendingAppends() => _revision++;

  @override
  Future<HMusicQueue> getQueue() async => _decode(await _store.read('queue'));

  @override
  Future<HMusicQueue> replaceQueue({
    required List<HMusicTrack> tracks,
    int? currentIndex,
    PlayMode? playMode,
  }) {
    _revision++;
    return _store.update('queue', (data) {
      final old = _decode(data);
      final now = DateTime.now().millisecondsSinceEpoch;
      return _save(
        data,
        HMusicQueue(
          sessionId: 'direct',
          items: [
            for (final track in tracks)
              HMusicQueueItem(id: _id(), track: track, addedAt: now),
          ],
          currentIndex: tracks.isEmpty
              ? -1
              : (currentIndex ?? old.currentIndex).clamp(-1, tracks.length - 1),
          playMode: _mode(playMode ?? old.playMode),
          updatedAt: now,
        ),
      );
    });
  }

  // 在同一存储事务内核实队列代数，迟到的榜单搜索不能写入新队列。
  Future<bool> appendIfCurrent(
    HMusicTrack track, {
    required int revision,
    required bool Function() isCurrent,
  }) => _store.update('queue', (data) {
    if (_revision != revision || !isCurrent()) return false;
    final old = _decode(data);
    final now = DateTime.now().millisecondsSinceEpoch;
    _save(
      data,
      HMusicQueue(
        sessionId: old.sessionId,
        items: [
          ...old.items,
          HMusicQueueItem(id: _id(), track: track, addedAt: now),
        ],
        currentIndex: old.currentIndex,
        playMode: old.playMode,
        updatedAt: now,
      ),
    );
    return true;
  });

  @override
  Future<HMusicQueue> addTrack(HMusicTrack track) =>
      _store.update('queue', (data) {
        final old = _decode(data);
        final now = DateTime.now().millisecondsSinceEpoch;
        return _save(
          data,
          HMusicQueue(
            sessionId: 'direct',
            items: [
              ...old.items,
              HMusicQueueItem(id: _id(), track: track, addedAt: now),
            ],
            currentIndex: old.currentIndex,
            playMode: old.playMode,
            updatedAt: now,
          ),
        );
      });

  @override
  Future<HMusicQueue> setCurrentIndex(int index) =>
      _store.update('queue', (data) {
        final old = _decode(data);
        if (index < -1 || index >= old.items.length) {
          throw const ApiFailure(
            kind: ApiFailureKind.invalidConfiguration,
            message: '队列位置已变化，请刷新后重试',
          );
        }
        return _save(
          data,
          HMusicQueue(
            sessionId: 'direct',
            items: old.items,
            currentIndex: index,
            playMode: old.playMode,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      });

  @override
  Future<HMusicQueue> setPlayMode(PlayMode playMode) =>
      _store.update('queue', (data) {
        final old = _decode(data);
        return _save(
          data,
          HMusicQueue(
            sessionId: 'direct',
            items: old.items,
            currentIndex: old.currentIndex,
            playMode: _mode(playMode),
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      });

  @override
  Future<HMusicQueue> clear() => replaceQueue(tracks: [], currentIndex: -1);

  static HMusicQueue _decode(Map<String, Object?> data) => data.isEmpty
      ? const HMusicQueue(
          sessionId: 'direct',
          items: [],
          currentIndex: -1,
          playMode: PlayMode.listLoop,
          updatedAt: 0,
        )
      : HMusicQueue.fromJson(data);

  static HMusicQueue _save(Map<String, Object?> data, HMusicQueue queue) {
    data
      ..clear()
      ..addAll(queue.toJson());
    return queue;
  }

  static PlayMode _mode(PlayMode mode) =>
      mode == PlayMode.unknown ? PlayMode.listLoop : mode;
  static String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
}
