import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart' as server;
import 'package:hmusic/core/platform_shell/platform_shell_bridge.dart';
import 'package:hmusic/core/platform_shell/platform_shell_controller.dart';
import 'package:hmusic/features/player/view_models/player_view_model.dart';

class FakeShellBridge implements PlatformShellBridge {
  // ignore: close_sinks - 测试 tearDown 关闭。
  final intentController = StreamController<ShellIntent>.broadcast();
  // ignore: close_sinks - 测试 tearDown 关闭。
  final readyController = StreamController<ShellReady>.broadcast();
  // ignore: close_sinks - 测试 tearDown 关闭。
  final layoutController = StreamController<ShellLayout>.broadcast();

  String? lastTab;
  String? lastTitle;
  bool? lastCanGoBack;
  bool configuredDark = false;
  final configurations = <(bool, bool, bool)>[];
  (String?, String?, String?, String?, bool)? lastNowPlaying;
  String? lastOutputLabel;
  int nowPlayingUpdates = 0;
  (bool, bool)? lastLayout;
  (double, double, double)? lastMiniMetrics;
  bool? lastAllowMinimize;
  final scrollReports = <bool>[];

  @override
  Stream<ShellReady> get readyEvents => readyController.stream;

  @override
  Stream<ShellLayout> get layoutChanges => layoutController.stream;

  @override
  Stream<ShellIntent> get intents => intentController.stream;

  @override
  Future<void> configure({
    required bool darkMode,
    required bool reduceMotion,
    required bool reduceTransparency,
  }) async {
    configuredDark = darkMode;
    configurations.add((darkMode, reduceMotion, reduceTransparency));
  }

  @override
  Future<void> updateNavigation({
    required String selectedTab,
    required String title,
    required bool canGoBack,
  }) async {
    lastTab = selectedTab;
    lastTitle = title;
    lastCanGoBack = canGoBack;
  }

  @override
  Future<void> updateNowPlaying({
    required String? trackId,
    required String? title,
    required String? artist,
    required String? artworkUrl,
    required bool playing,
    required String outputLabel,
  }) async {
    lastNowPlaying = (trackId, title, artist, artworkUrl, playing);
    lastOutputLabel = outputLabel;
    nowPlayingUpdates++;
  }

  @override
  Future<void> updateLayout({
    required bool showTabBar,
    required bool showMiniPlayer,
    required double miniPlayerHeight,
    required double miniTitleFontSize,
    required double miniDetailFontSize,
    required bool allowMinimize,
  }) async {
    lastLayout = (showTabBar, showMiniPlayer);
    lastMiniMetrics = (miniPlayerHeight, miniTitleFontSize, miniDetailFontSize);
    lastAllowMinimize = allowMinimize;
  }

  @override
  Future<void> updateScroll({required bool minimized}) async {
    scrollReports.add(minimized);
  }

  void dispose() {
    unawaited(intentController.close());
    unawaited(readyController.close());
    unawaited(layoutController.close());
  }
}

class RecordingShellPlayer implements PlayerViewModel {
  final calls = <String>[];

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seek(Duration position) async => calls.add('seek');

  @override
  Future<void> skipToNext() async => calls.add('next');

  @override
  Future<void> setDeviceVolume(int volume) async =>
      calls.add('setDeviceVolume');

  @override
  Future<void> skipToPrevious() async => calls.add('previous');

  @override
  Future<void> setPlayMode(server.PlayMode mode) async => calls.add('mode');

  @override
  Future<void> setLocalVolume(double volume) async => calls.add('volume');

  @override
  Future<double> readLocalVolume() async => 0.5;
}

GoRouter createShellRouter() => GoRouter(
  initialLocation: '/search',
  routes: <RouteBase>[
    for (final (path, label) in <(String, String)>[
      ('/search', 'search'),
      ('/charts', 'charts'),
      ('/playlists', 'library'),
      ('/stats', 'stats'),
      ('/settings', 'settings'),
      ('/player', 'player'),
      ('/outputs', 'outputs'),
    ])
      GoRoute(
        path: path,
        builder: (context, state) => Scaffold(body: Text(label)),
      ),
  ],
);

void useMobileShellViewport(PlatformShellController controller) {
  controller.updateViewport(
    useBottomChrome: true,
    miniPlayerHeight: 50,
    miniTitleFontSize: 14,
    miniDetailFontSize: 12,
    allowMinimize: true,
  );
}
