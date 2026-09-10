import 'direct_music_http.dart';
import 'platform_track_mapper.dart';

class DirectResolvedAudio {
  const DirectResolvedAudio(this.uri, {this.headers = const {}});

  factory DirectResolvedAudio.fromSource(Object? value) {
    final data = musicMap(value);
    return DirectResolvedAudio(
      validateMusicUri(value is String ? value : '${data['url'] ?? ''}'),
      headers: musicMap(
        data['headers'],
      ).map((key, value) => MapEntry(key, '$value')),
    );
  }

  final Uri uri;
  final Map<String, String> headers;
}
