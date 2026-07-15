import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart' as server;
import 'package:hmusic/core/platform_shell/platform_shell_bridge.dart';
import 'package:hmusic/core/platform_shell/platform_shell_controller.dart';
import 'package:hmusic/features/player/view_models/player_view_model.dart';
import 'package:hmusic/features/player/views/player_page.dart';
import 'package:hmusic/features/queue/views/queue_page.dart';
import 'package:hmusic/features/search/views/search_page.dart';

class _FakeBridge implements PlatformShellBridge {
  // ignore: close_sinks - closed in tearDown
  final StreamController<ShellIntentType> intentController =
      StreamController<ShellIntentType>.broadcast();

  String? lastTab;
  String? lastTitle;
  bool? lastCanGoBack;
  bool configuredDark = false;

  @override
  Stream<ShellLayout> get layoutChanges => const Stream<ShellLayout>.empty();

  @override
  Stream<ShellIntentType> get intents => intentController.stream;

  @override
  Future<void> configure({
    required bool darkMode,
    required bool reduceMotion,
    required bool reduceTransparency,
  }) async {
    configuredDark = darkMode;
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
}

class _RecordingPlayerViewModel implements PlayerViewModel {
  final List<String> calls = <String>[];

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seek(Duration position) async => calls.add('seek');

  @override
  Future<void> skipToNext() async => calls.add('next');

  @override
  Future<void> skipToPrevious() async => calls.add('previous');

  @override
  Future<void> setPlayMode(server.PlayMode mode) async => calls.add('mode');

  @override
  Future<void> setLocalVolume(double volume) async => calls.add('volume');

  @override
  Future<double> readLocalVolume() async => 0.5;
}

Widget _placeholder(String label) => Scaffold(body: Text(label));

GoRouter _router() => GoRouter(
  initialLocation: SearchPage.path,
  routes: <RouteBase>[
    GoRoute(
      path: SearchPage.path,
      builder: (context, state) => _placeholder('search'),
    ),
    GoRoute(
      path: QueuePage.path,
      builder: (context, state) => _placeholder('queue'),
    ),
    GoRoute(
      path: PlayerPage.path,
      builder: (context, state) => _placeholder('player'),
    ),
  ],
);

void main() {
  late _FakeBridge bridge;
  late _RecordingPlayerViewModel player;
  late PlatformShellController controller;
  late GoRouter router;

  setUp(() {
    bridge = _FakeBridge();
    player = _RecordingPlayerViewModel();
    router = _router();
    controller = PlatformShellController(
      bridge: bridge,
      router: router,
      playerViewModel: player,
    );
  });

  tearDown(() {
    controller.dispose();
    unawaited(bridge.intentController.close());
  });

  testWidgets('openNowPlaying pushes the player route', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    controller.handleIntent(ShellIntentType.openNowPlaying);
    await tester.pumpAndSettle();
    expect(find.text('player'), findsOneWidget);
  });

  testWidgets('selectTab switches to queue route', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await controller.syncNavigation(selectedTab: 'queue', title: '播放队列');
    controller.handleIntent(ShellIntentType.selectTab);
    await tester.pumpAndSettle();
    expect(find.text('queue'), findsOneWidget);
  });

  test('media intents dispatch to PlayerViewModel', () async {
    controller.handleIntent(ShellIntentType.playPause);
    controller.handleIntent(ShellIntentType.previous);
    controller.handleIntent(ShellIntentType.next);
    await pumpEventQueue();
    expect(player.calls, <String>['play', 'previous', 'next']);
  });

  test('seek and dismiss are ignored silently in P0', () async {
    controller.handleIntent(ShellIntentType.seek);
    controller.handleIntent(ShellIntentType.dismiss);
    await pumpEventQueue();
    expect(player.calls, isEmpty);
  });

  test('syncNavigation and configure push to native bridge', () async {
    await controller.syncNavigation(
      selectedTab: 'search',
      title: '搜索',
      canGoBack: true,
    );
    await controller.configure(
      darkMode: true,
      reduceMotion: false,
      reduceTransparency: false,
    );
    expect(bridge.lastTab, 'search');
    expect(bridge.lastTitle, '搜索');
    expect(bridge.lastCanGoBack, true);
    expect(bridge.configuredDark, true);
  });
}
