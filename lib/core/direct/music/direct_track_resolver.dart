import '../../models/hmusic_track.dart';
import '../../network/api_failure.dart';
import '../storage/direct_local_store.dart';
import 'direct_audio_probe.dart';
import 'direct_lx_sources.dart';
import 'direct_music_http.dart';
import 'direct_music_search.dart';
import 'direct_resolved_audio.dart';
import 'direct_song_matcher.dart';
import 'lx_music_info.dart';

export 'direct_resolved_audio.dart';

class DirectTrackResolver {
  DirectTrackResolver(this._sources, this._search, this._store);
  final DirectLxSources _sources;
  final DirectMusicSearch _search;
  final DirectLocalStore _store;
  final Map<String, ({int count, DateTime retryAt})> _failures = {};

  Future<DirectResolvedAudio> resolve(HMusicTrack track) async {
    if (track.url case final url? when url.isNotEmpty) {
      return DirectResolvedAudio(validateMusicUri(url));
    }
    final config = await _store.read('config');
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    final preferred = switch (config['resolveStrategy']) {
      'qqFirst' => 'tx',
      'kuwoFirst' => 'kw',
      'neteaseFirst' => 'wy',
      _ => track.source,
    };
    final ordered = <String>{
      preferred,
      track.source,
      'tx',
      'kw',
      'wy',
    }.where((source) => const ['tx', 'kw', 'wy'].contains(source)).toList();
    final now = DateTime.now();
    // 熔断平台后移，冷却后允许探测；全部失败时仍保留一次原平台重试。
    final platforms = [
      ...ordered.where((source) => _open(source, now) == 0),
      ...ordered.where((source) => _open(source, now) != 0),
    ];
    ApiFailure? lastFailure;
    for (final source in platforms) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining.isNegative || remaining == Duration.zero) break;
      try {
        final target = source == track.source
            ? track
            : matchDirectSong(
                track,
                await _search
                    .search('${track.title} ${track.artist}', source: source)
                    .timeout(
                      remaining,
                      onTimeout: () => throw const ApiFailure(
                        kind: ApiFailureKind.timeout,
                        message: '歌曲匹配超时，请重试',
                      ),
                    ),
              );
        if (target == null) continue;
        late DirectResolvedAudio audio;
        await _sources.resolve(
          source,
          'musicUrl',
          {
            'type': config['defaultQuality'] ?? '320k',
            'musicInfo': lxMusicInfo(target),
          },
          deadline: deadline,
          validate: (value) async {
            final candidate = DirectResolvedAudio.fromSource(value);
            await const DirectAudioProbe().check(candidate, deadline: deadline);
            audio = candidate;
          },
        );
        _failures.remove(source);
        return audio;
      } on ApiFailure catch (failure) {
        if (failure.code == 'DIRECT_SOURCE_MISSING' ||
            failure.code == 'DIRECT_SOURCE_CHANGED') {
          rethrow;
        }
        lastFailure = failure;
        _failures[source] = (
          count: (_failures[source]?.count ?? 0) + 1,
          retryAt: now.add(const Duration(minutes: 1)),
        );
      }
    }
    throw lastFailure ??
        const ApiFailure(kind: ApiFailureKind.server, message: '未找到可播放的匹配歌曲');
  }

  int _open(String platform, DateTime now) {
    final failure = _failures[platform];
    return failure != null &&
            failure.count >= 3 &&
            now.isBefore(failure.retryAt)
        ? 1
        : 0;
  }
}
