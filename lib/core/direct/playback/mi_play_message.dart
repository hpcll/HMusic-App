import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../models/hmusic_track.dart';
import '../../network/api_failure.dart';
import '../mi_direct_device.dart';

class MiPlayMessage {
  const MiPlayMessage({required this.method, required this.message});

  factory MiPlayMessage.forTrack({
    required MiDirectDevice device,
    required HMusicTrack track,
    required Uri stream,
    int positionMs = 0,
    bool? usePlayMusic,
  }) {
    if (!['http', 'https'].contains(stream.scheme) ||
        stream.host.isEmpty ||
        stream.userInfo.isNotEmpty ||
        stream.hasFragment ||
        positionMs < 0) {
      throw const ApiFailure(
        kind: ApiFailureKind.invalidConfiguration,
        code: 'MI_DIRECT_STREAM_INVALID',
        message: '音频地址或播放位置无效',
      );
    }
    final profile = device.profile;
    final media = profile.media;
    if (!(usePlayMusic ?? profile.needsPlayMusicApi)) {
      return MiPlayMessage(
        method: 'player_play_url',
        message: {
          'url': stream.toString(),
          'type': 2,
          'media': media,
          if (track.durationMs != null) 'duration': track.durationMs,
        },
      );
    }
    final audioId = audioIdFor(track, stream);
    return MiPlayMessage(
      method: 'player_play_music',
      message: {
        'startaudioid': audioId,
        'music': jsonEncode({
          'payload': {
            'audio_type': '',
            'audio_items': [
              {
                'item_id': {
                  'audio_id': audioId,
                  'cp': {
                    'album_id': '-1',
                    'episode_index': 0,
                    'id': '355454500',
                    'name': 'xiaowei',
                  },
                },
                'stream': {'url': stream.toString()},
              },
            ],
            'list_params': {
              'listId': '-1',
              'loadmore_offset': 0,
              'origin': 'xiaowei',
              'type': 'MUSIC',
            },
          },
          'play_behavior': 'REPLACE_ALL',
        }),
        'media': media,
        if (track.durationMs != null) 'duration': track.durationMs,
        if (positionMs > 0 && profile.supportsStartOffset)
          'startOffset': positionMs,
      },
    );
  }

  final String method;
  final Map<String, Object?> message;

  static String audioIdFor(HMusicTrack track, Uri stream) {
    if (stream.host == 'qqmusic.qq.com' ||
        stream.host.endsWith('.qqmusic.qq.com')) {
      final file = stream.pathSegments.lastOrNull ?? '';
      if (file.startsWith('C400') && file.endsWith('.m4a') && file.length > 8) {
        return file.substring(4, file.length - 4);
      }
    }
    // 保留稳定数字 audio_id；以平台曲目身份哈希，避免旧版字符求和对同名/换序曲目碰撞。
    final bytes = sha1
        .convert(utf8.encode('${track.source}:${track.sourceTrackId}'))
        .bytes;
    final hash = bytes
        .take(4)
        .fold<int>(0, (value, byte) => value * 256 + byte);
    return ((hash % 999999999) + 100000000).toString();
  }
}
