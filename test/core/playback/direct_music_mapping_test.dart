import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/music/direct_audio_policy.dart';
import 'package:hmusic/core/direct/music/direct_music_http.dart';
import 'package:hmusic/core/direct/music/direct_song_matcher.dart';
import 'package:hmusic/core/direct/music/direct_track_resolver.dart';
import 'package:hmusic/core/direct/music/lx_music_info.dart';
import 'package:hmusic/core/direct/music/platform_track_mapper.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/features/player/data/direct_lyric_repository.dart';

void main() {
  test('QQ mid is preferred over numeric id and raw plugin fields survive', () {
    final raw = <String, Object?>{
      'id': 999,
      'mid': '003Abcd',
      'title': 'A &amp; B',
      'interval': 123,
      'album': {'mid': 'album123', 'name': 'Album'},
      'singer': [
        {'name': 'Singer'},
      ],
      'file': {'media_mid': 'file-mid'},
    };
    final track = PlatformTrackMapper.qq(raw);
    expect(track.sourceTrackId, '003Abcd');
    expect(track.durationMs, 123000);
    expect(track.title, 'A & B');
    expect(track.raw, raw);
    expect(lxMusicInfo(track)['songmid'], '003Abcd');
  });
  test(
    'Kuwo uses rid and mm:ss while Netease retains millisecond duration',
    () {
      final kw = PlatformTrackMapper.kuwo({
        'MUSICRID': 'MUSIC_124',
        'SONGNAME': '歌',
        'DURATION': '03:21',
      });
      expect(kw.sourceTrackId, '124');
      expect(kw.durationMs, 201000);
      final wy = PlatformTrackMapper.netease({
        'id': 124,
        'name': '歌',
        'dt': 201123,
        'ar': [
          {'name': '歌手'},
        ],
      });
      expect(wy.durationMs, 201123);
      expect(wy.artist, '歌手');
    },
  );
  test('LRC handles repeated timestamps, fractions and signed offsets', () {
    final lines = parseDirectLrc(
      '[offset:-200]\n[00:03.5][00:01.050]一句歌词\n[00:00.1]开头',
    );
    expect(lines.map((line) => line.timeMs), [0, 850, 3300]);
    expect(lines.last.text, '一句歌词');
  });
  test(
    'cross-platform matching rejects cover artists and alternate versions',
    () {
      const track = HMusicTrack(
        id: 'wy:1',
        source: 'wy',
        sourceTrackId: '1',
        title: '晴天',
        artist: '周杰伦',
        durationMs: 269000,
      );
      HMusicTrack candidate(String title, String artist, int duration) =>
          HMusicTrack(
            id: 'tx:2',
            source: 'tx',
            sourceTrackId: '2',
            title: title,
            artist: artist,
            durationMs: duration,
          );
      expect(matchDirectSong(track, [candidate('晴天', '翻唱歌手', 269000)]), isNull);
      expect(
        matchDirectSong(track, [candidate('晴天 (Live)', '周杰伦', 320000)]),
        isNull,
      );
      expect(
        matchDirectSong(track, [candidate('晴天', '周杰伦', 268000)])?.id,
        'tx:2',
      );
    },
  );
  test(
    'CDN header policy matches domain boundaries and rejects credential-bearing URIs',
    () {
      expect(DirectAudioPolicy.isQq('c6.y.qqmusic.qq.com'), isTrue);
      expect(
        DirectAudioPolicy.isQq('qqmusic.qq.com.attacker.example'),
        isFalse,
      );
      expect(
        DirectAudioPolicy.needsProxy(
          DirectResolvedAudio(Uri.parse('https://qqmusic.qq.com/a')),
        ),
        isTrue,
      );
      expect(
        DirectAudioPolicy.needsProxy(
          DirectResolvedAudio(Uri.parse('https://qqmusic.qq.com/a')),
          qqDirect: true,
        ),
        isFalse,
      );
      for (final url in [
        'file:///private/a',
        'https://user:secret@audio.example/a',
        'https://audio.example/a#frag',
        'https://audio.example/a\n',
      ]) {
        expect(() => validateMusicUri(url), throwsA(isA<ApiFailure>()));
      }
    },
  );
}
