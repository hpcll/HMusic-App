import 'direct_resolved_audio.dart';

class DirectAudioPolicy {
  static bool hostIs(String host, String domain) =>
      host == domain || host.endsWith('.$domain');

  static bool isQq(String host) =>
      hostIs(host, 'qqmusic.qq.com') || hostIs(host, 'music.tc.qq.com');
  static bool isKuwo(String host) =>
      hostIs(host, 'kuwo.cn') || hostIs(host, 'kuwo.com');

  static Map<String, String> headers(DirectResolvedAudio audio) => {
    if (isQq(audio.uri.host)) 'Referer': 'https://y.qq.com/',
    if (isKuwo(audio.uri.host)) 'Referer': 'https://www.kuwo.cn/',
    if (isQq(audio.uri.host) || isKuwo(audio.uri.host))
      'User-Agent': 'Mozilla/5.0',
    ...audio.headers,
  };

  static bool needsProxy(DirectResolvedAudio audio, {bool qqDirect = false}) =>
      audio.headers.isNotEmpty ||
      isKuwo(audio.uri.host) ||
      (isQq(audio.uri.host) && !qqDirect);
}
