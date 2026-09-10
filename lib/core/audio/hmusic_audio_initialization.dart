part of 'hmusic_audio_handler.dart';

final Provider<LocalVolumeStore> localVolumeStoreProvider =
    Provider<LocalVolumeStore>(
      (ref) => SharedPreferencesLocalVolumeStore(
        preferences: ref.watch(keyValueStoreProvider),
      ),
    );

final FutureProvider<HMusicAudioHandler> hmusicAudioHandlerProvider =
    FutureProvider<HMusicAudioHandler>((ref) async {
      // 音频会话必须在建 player 前配置好（docs/08）：装了 audio_session 却不
      // configure，iOS/Android 会按「未声明用途」的默认会话走——静音键掐掉播放、
      // 来电中断后不恢复。music() 预设声明本 App 是音乐播放器。
      // 注意 macOS 侧该插件是空实现（只存配置并广播，AVAudioSession 为 iOS 专有），
      // 桌面端的输出质量问题不在这条链路上，别指望改这里能解决。
      await AudioSession.instance.then(
        (session) => session.configure(const AudioSessionConfiguration.music()),
      );
      final handler = await AudioService.init(
        builder: () => HMusicAudioHandler(
          playbackRepository: ref.watch(playbackRepositoryProvider),
          streamUrlRebaser: ModeStreamUrlRebaser(
            serverConfigStore: ref.watch(serverConfigStoreProvider),
            mode: () => ref.read(playbackModeProvider),
          ),
          localVolumeStore: ref.watch(localVolumeStoreProvider),
          capabilities: ref.watch(clientPlaybackCapabilitiesProvider),
          backendGeneration: () =>
              ref.read(playbackModeProvider.notifier).generation,
        ),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.hupc.hmusic.playback',
          androidNotificationChannelName: 'HMusic 播放',
          androidNotificationOngoing: true,
        ),
      );
      ref.onDispose(() => unawaited(handler.disposeHandler()));
      // 冷启动接续（音箱可能还在播）：不等播放页首订，handler 就绪即拉一次
      // 服务端状态，首页的 mini player/dock 立刻有「正在播放」。失败静默——
      // 播放页订阅 serverPlaybackStateProvider 时会再兜底拉取并如实报错。
      unawaited(handler.ensureServerState().catchError((Object _) {}));
      return handler;
    });
