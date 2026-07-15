import '../audio/models/hmusic_playback_state.dart' show PlayMode;
import '../models/hmusic_track.dart';
import 'models/hmusic_queue.dart';

abstract interface class QueueRepository {
  Future<HMusicQueue> getQueue();

  Future<HMusicQueue> replaceQueue({
    required List<HMusicTrack> tracks,
    int? currentIndex,
    PlayMode? playMode,
  });

  Future<HMusicQueue> addTrack(HMusicTrack track);

  Future<HMusicQueue> setCurrentIndex(int index);

  Future<HMusicQueue> setPlayMode(PlayMode playMode);

  Future<HMusicQueue> clear();
}
