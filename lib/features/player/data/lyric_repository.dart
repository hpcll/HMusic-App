import '../../../core/models/hmusic_track.dart';
import '../models/hmusic_lyric.dart';

// 歌词仓库（对齐 web /tracks/lyrics）。按曲拉取行级 LRC；无歌词不算错误。
abstract interface class LyricRepository {
  // 拉取某曲歌词。服务端按 track 快照解析，返回行级时间戳（可能为空）。
  Future<HMusicLyric> fetchLyric(HMusicTrack track);
}
