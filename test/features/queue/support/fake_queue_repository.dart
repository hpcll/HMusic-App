import 'dart:async';

import 'package:hmusic/core/audio/models/hmusic_playback_state.dart'
    show PlayMode;
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/queue/models/hmusic_queue.dart';
import 'package:hmusic/core/queue/queue_repository.dart';

HMusicTrack buildTrack(int i) => HMusicTrack(
  id: 'tx:$i',
  source: 'tx',
  sourceTrackId: '$i',
  title: '曲目$i',
  artist: '歌手$i',
);

HMusicQueue buildQueue({int count = 3, int currentIndex = 0}) => HMusicQueue(
  sessionId: 's1',
  items: <HMusicQueueItem>[
    for (var i = 0; i < count; i++)
      HMusicQueueItem(id: 'q$i', track: buildTrack(i), addedAt: i),
  ],
  currentIndex: currentIndex,
  playMode: PlayMode.listLoop,
  updatedAt: 1,
);

class FakeQueueRepository implements QueueRepository {
  FakeQueueRepository({required this.queue});

  HMusicQueue queue;
  final List<String> calls = <String>[];

  // 非空时写响应挂起，由测试放行——用于制造互斥窗口。
  Completer<void>? gate;
  ApiFailure? failure;

  Future<HMusicQueue> _respond(String call) async {
    calls.add(call);
    final pending = gate;
    if (pending != null) await pending.future;
    final error = failure;
    if (error != null) throw error;
    return queue;
  }

  @override
  Future<HMusicQueue> getQueue() => _respond('get');

  @override
  Future<HMusicQueue> replaceQueue({
    required List<HMusicTrack> tracks,
    int? currentIndex,
    PlayMode? playMode,
  }) => _respond('replace:${tracks.length}:$currentIndex');

  @override
  Future<HMusicQueue> addTrack(HMusicTrack track) =>
      _respond('add:${track.id}');

  @override
  Future<HMusicQueue> setCurrentIndex(int index) => _respond('current:$index');

  @override
  Future<HMusicQueue> setPlayMode(PlayMode playMode) =>
      _respond('mode:${playMode.name}');

  @override
  Future<HMusicQueue> clear() => _respond('clear');
}
