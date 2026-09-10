import '../../models/hmusic_track.dart';
import 'platform_track_mapper.dart';

Map<String, Object?> lxMusicInfo(HMusicTrack track) {
  final raw = musicMap(track.raw),
      album = musicMap(musicMap(track.raw)['album']);
  final file = musicMap(raw['file']);
  return {
    ...raw,
    'songmid': track.sourceTrackId,
    'songId': track.sourceTrackId,
    'id': track.sourceTrackId,
    'hash': track.sourceTrackId,
    'strMediaMid':
        file['media_mid'] ?? raw['strMediaMid'] ?? track.sourceTrackId,
    'name': track.title,
    'singer': track.artist,
    'album': track.album ?? '',
    'albumMid': album['mid'] ?? raw['albummid'] ?? '',
    'albumId': album['id'] ?? raw['albumid'] ?? '',
    'duration': (track.durationMs ?? 0) ~/ 1000,
    'interval': (track.durationMs ?? 0) ~/ 1000,
  };
}
