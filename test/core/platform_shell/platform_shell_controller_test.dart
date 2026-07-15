import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart' as server;
import 'package:hmusic/core/platform_shell/platform_shell_bridge.dart';
import 'package:hmusic/core/platform_shell/platform_shell_controller.dart';
import 'package:hmusic/features/charts/views/charts_page.dart';
import 'package:hmusic/features/player/view_models/player_view_model.dart';
import 'package:hmusic/features/player/views/player_page.dart';
import 'package:hmusic/features/search/views/search_page.dart';
import 'package:hmusic/features/settings/views/settings_page.dart';

class _FakeBridge implements PlatformShellBridge {
  // ignore: close_sinks - closed in tearDown
  final StreamController<ShellIntent> intentController =
      StreamController<ShellIntent>.broadcast();
  // ignore: close_sinks - closed in tearDown
  final StreamController<ShellReady> readyController =
      StreamController<ShellReady>.broadcast();
  // ignore: close_sinks - closed in tearDown
  final StreamController<ShellLayout> layoutController =
      StreamController<ShellLayout>.broadcast();

  String? lastTab;
  String? lastTitle;
  bool? lastCanGoBack;
  bool configuredDark = false;
  (String?, String?, String?, String?, bool)? lastNowPlaying;
  (bool, bool)? lastLayout;
  final List<bool> scrollReports = <bool>[];

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
  }) async {
    lastNowPlaying = (trackId, title, artist, artworkUrl, playing);
  }

  @override
  Future<void> updateLayout({
    required bool showTabBar,
    required bool showMiniPlayer,
  }) async {
    lastLayout = (showTabBar, showMiniPlayer);
  }

  @override
  Future<void> updateScroll({required bool minimized}) async {
    scrollReports.add(minimized);
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
      path: ChartsPage.path,
      builder: (context, state) => _placeholder('charts'),
    ),
    GoRoute(
      path: SettingsPage.path,
      builder: (context, state) => _placeholder('settings'),
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
    router.dispose();
    unawaited(bridge.intentController.close());
    unawaited(bridge.readyController.close());
    unawaited(bridge.layoutController.close());
  });

  testWidgets('openNowPlaying pushes the player route', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    controller.handleIntent(const ShellIntent(ShellIntentType.openNowPlaying));
    await tester.pumpAndSettle();
    expect(find.text('player'), findsOneWidget);
  });

  testWidgets('selectTab intent value routes to that tab', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    controller.handleIntent(
      const ShellIntent(ShellIntentType.selectTab, 'charts'),
    );
    await tester.pumpAndSettle();
    expect(find.text('charts'), findsOneWidget);
  });

  testWidgets('unknown selectTab value is ignored', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    controller.handleIntent(
      const ShellIntent(ShellIntentType.selectTab, 'nope'),
    );
    await tester.pumpAndSettle();
    expect(find.text('search'), findsOneWidget);
  });

  testWidgets('route change pushes navigation and layout to bridge', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go(SettingsPage.path);
    await tester.pumpAndSettle();
    expect(bridge.lastTab, 'settings');
    expect(bridge.lastTitle, '设置');
    expect(bridge.lastLayout, (true, true));
  });

  testWidgets('full-screen route hides native chrome', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go(SettingsPage.path);
    await tester.pumpAndSettle();
    unawaited(router.push(PlayerPage.path));
    await tester.pumpAndSettle();
    expect(bridge.lastLayout, (false, false));
  });

  test('media intents dispatch to PlayerViewModel', () async {
    controller.handleIntent(const ShellIntent(ShellIntentType.playPause));
    controller.handleIntent(const ShellIntent(ShellIntentType.previous));
    controller.handleIntent(const ShellIntent(ShellIntentType.next));
    await pumpEventQueue();
    expect(player.calls, <String>['play', 'previous', 'next']);
  });

  test('seek and dismiss are ignored silently in P0', () async {
    controller.handleIntent(const ShellIntent(ShellIntentType.seek));
    controller.handleIntent(const ShellIntent(ShellIntentType.dismiss));
    await pumpEventQueue();
    expect(player.calls, isEmpty);
  });

  test('ready with bottomBar+miniPlayer activates native chrome', () async {
    expect(controller.nativeChromeActive, isFalse);
    bridge.readyController.add(
      const ShellReady(capabilities: <String>['bottomBar', 'miniPlayer']),
    );
    await pumpEventQueue();
    expect(controller.nativeChromeActive, isTrue);
    // ready 触发全量补发：navigation + layout + configure 都应到达桥。
    expect(bridge.lastLayout, isNotNull);
    expect(bridge.lastTab, isNotNull);
  });

  test('ready with empty capabilities keeps Flutter chrome', () async {
    bridge.readyController.add(const ShellReady(capabilities: <String>[]));
    await pumpEventQueue();
    expect(controller.nativeChromeActive, isFalse);
  });

  test('layoutChanged exposes native bottom inset', () async {
    bridge.layoutController.add(
      const ShellLayout(topInset: 0, bottomInset: 92),
    );
    await pumpEventQueue();
    expect(controller.nativeBottomInset, 92);
  });

  test('scroll reports dedupe and require active native chrome', () async {
    // 原生未接管：不上报。
    controller.reportScroll(minimized: true);
    expect(bridge.scrollReports, isEmpty);

    bridge.readyController.add(
      const ShellReady(capabilities: <String>['bottomBar', 'miniPlayer']),
    );
    await pumpEventQueue();

    controller.reportScroll(minimized: true);
    controller.reportScroll(minimized: true); // 重复值去重
    controller.reportScroll(minimized: false);
    expect(bridge.scrollReports, <bool>[true, false]);
  });
}
