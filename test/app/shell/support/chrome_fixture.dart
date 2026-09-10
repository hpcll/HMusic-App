import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/app/shell/flutter_glass_shell.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/core/upgrade/app_update_badge.dart';

import '../../../features/player/support/playback_ui_fixture.dart';

export '../../../features/player/support/playback_ui_fixture.dart';

const chromeCaptureKey = ValueKey('chrome-review-surface');

class _NoUpdateBadge extends AppUpdateBadge {
  @override
  String build() => '';
}

HMusicPlaybackState idlePlayback() => HMusicPlaybackState.fromJson({
  ...uiPlayback().toJson(),
  'track': null,
  'state': 'idle',
  'queueLength': 0,
});

Future<GoRouter> pumpChrome(
  WidgetTester tester,
  PlaybackUiFixture fixture, {
  double width = 390,
  double scale = 1,
  bool dark = false,
  bool reduceMotion = false,
  bool highContrast = false,
  int initialBranch = 4,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(fixture.handler.disposeHandler);
  final router = GoRouter(
    initialLocation: '/b$initialBranch',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            FlutterGlassShell(shell: shell, showMini: true),
        branches: [
          for (var i = 0; i < 7; i++)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/b$i',
                  builder: (context, state) => ListView.builder(
                    key: ValueKey('page-$i'),
                    padding: EdgeInsets.fromLTRB(
                      20,
                      56,
                      20,
                      MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: 30,
                    itemExtent: 96,
                    itemBuilder: (context, index) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.music_note_rounded),
                        title: Text(
                          '音乐推荐 ${index + 1}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: const Text(
                          '发现更多好音乐',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      for (final path in ['/search', '/player'])
        GoRoute(
          path: path,
          builder: (context, state) => Scaffold(body: Text('overlay-$path')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    fixture.scope(
      ProviderScope(
        overrides: [appUpdateBadgeProvider.overrideWith(_NoUpdateBadge.new)],
        child: MaterialApp.router(
          theme: (dark ? HMusicTheme.dark() : HMusicTheme.light()).copyWith(
            platform: TargetPlatform.android,
          ),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 24, bottom: 16),
              viewPadding: const EdgeInsets.only(top: 24, bottom: 16),
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduceMotion,
              highContrast: highContrast,
            ),
            child: RepaintBoundary(key: chromeCaptureKey, child: child!),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<TestGesture> beginChromeScroll(WidgetTester tester) async {
  final gesture = await tester.startGesture(const Offset(160, 500));
  await gesture.moveBy(const Offset(0, -180));
  await tester.pump();
  return gesture;
}
