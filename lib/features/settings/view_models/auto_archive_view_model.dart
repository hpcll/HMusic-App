import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/hmusic_audio_handler.dart';
import '../../../core/models/hmusic_track.dart';
import '../../../core/providers/infrastructure_providers.dart';
import '../data/api_downloads_repository.dart';

// 「播放过的在线歌自动入库」开关（默认关）。开着时每换一首在线曲目就发起一次
// 服务端下载：下次播放直接走本地文件，免直链过期、免解析等待——代价是服务器
// 硬盘默默变大，所以默认关，由用户在「本地下载」子页自己开。
//
// 状态落 KeyValueStore（只有 String/Double 两种口径，这里存 '1'/'0'）。
const String _autoArchiveKey = 'hmusic.downloads.autoArchive';

final NotifierProvider<AutoArchiveSetting, bool> autoArchiveEnabledProvider =
    NotifierProvider<AutoArchiveSetting, bool>(AutoArchiveSetting.new);

class AutoArchiveSetting extends Notifier<bool> {
  @override
  bool build() {
    unawaited(_restore());
    return false;
  }

  Future<void> _restore() async {
    final raw = await ref
        .read(keyValueStoreProvider)
        .getString(_autoArchiveKey);
    final enabled = raw == '1';
    if (enabled != state) state = enabled;
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    await ref
        .read(keyValueStoreProvider)
        .setString(_autoArchiveKey, value ? '1' : '0');
  }
}

// 自动入库的执行体：订阅权威播放状态，每换一首就按开关决定要不要下。
// 在 app 根激活（同 sessionGuard/appVersionGuard），这样从任何页面点播都算
// 「听过」，不只榜单。
//
// 三条跳过规则：开关关着不下；已经在放本地文件的不下（streamUrl 是服务端的
// /proxy/local/…，说明曲库里已经有了）；同一 trackKey 本次会话只发一次
// ——服务端对同一 trackKey 幂等，这条只是省掉重复请求。
final Provider<void> autoArchiveWatcherProvider = Provider<void>((ref) {
  final Set<String> attempted = <String>{};
  StreamSubscription<void>? subscription;
  unawaited(
    ref.read(hmusicAudioHandlerProvider.future).then((handler) {
      subscription = handler.serverStateStream.listen((state) {
        if (!ref.read(autoArchiveEnabledProvider)) return;
        final HMusicTrack? track = state.track;
        if (track == null) return;
        final url = state.streamUrl ?? '';
        if (url.contains('/proxy/local/')) return;
        final key = '${track.source}:${track.sourceTrackId}';
        if (!attempted.add(key)) return;
        unawaited(
          ref.read(downloadsRepositoryProvider).start(track).catchError((
            Object _,
          ) {
            // 自动入库是背景动作：失败不打扰用户（手动下载会报错）。
            attempted.remove(key);
          }),
        );
      });
    }),
  );
  ref.onDispose(() => unawaited(subscription?.cancel()));
});
