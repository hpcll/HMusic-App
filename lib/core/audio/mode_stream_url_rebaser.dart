import '../direct/music/direct_music_http.dart';
import '../playback/playback_mode.dart';
import 'stream_url_rebaser.dart';

class ModeStreamUrlRebaser extends StreamUrlRebaser {
  ModeStreamUrlRebaser({
    required super.serverConfigStore,
    required PlaybackMode Function() mode,
  }) : _mode = mode;
  final PlaybackMode Function() _mode;
  @override
  Future<Uri> rebase(String streamUrl) => _mode() == PlaybackMode.direct
      ? Future.value(validateMusicUri(streamUrl))
      : super.rebase(streamUrl);
}
