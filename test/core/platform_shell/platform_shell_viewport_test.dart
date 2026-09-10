import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/core/platform_shell/platform_shell_bridge.dart';
import 'package:hmusic/core/platform_shell/platform_shell_controller.dart';

import 'support/platform_shell_fixture.dart';

class _AudioHandler extends BaseAudioHandler {}

void main() {
  late FakeShellBridge bridge;
  late RecordingShellPlayer player;
  late PlatformShellController controller;
  late GoRouter router;
  late _AudioHandler audio;

  setUp(() {
    bridge = FakeShellBridge();
    player = RecordingShellPlayer();
    router = createShellRouter();
    audio = _AudioHandler();
    controller = PlatformShellController(
      bridge: bridge,
      router: router,
      playerViewModel: player,
    );
  });

  tearDown(() {
    controller.dispose();
    router.dispose();
    bridge.dispose();
    unawaited(audio.mediaItem.close());
    unawaited(audio.playbackState.close());
  });

  void reportReady() {
    bridge.readyController.add(
      const ShellReady(capabilities: <String>['bottomBar', 'miniPlayer']),
    );
  }

  void useWideViewport() {
    controller.updateViewport(
      useBottomChrome: false,
      miniPlayerHeight: 50,
      miniTitleFontSize: 14,
      miniDetailFontSize: 12,
      allowMinimize: true,
    );
  }

  test('viewport 未送达时 ready 不得抢先显示原生底栏', () async {
    reportReady();
    await pumpEventQueue();
    expect(controller.nativeChromeActive, isFalse);
    expect(bridge.lastLayout, (false, false));
  });

  testWidgets('不换路由的宽窄窗口切换更新原生显隐和内容 inset', (tester) async {
    useMobileShellViewport(controller);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/charts');
    reportReady();
    bridge.layoutController.add(
      const ShellLayout(topInset: 0, bottomInset: 178),
    );
    await tester.pumpAndSettle();
    expect(controller.nativeChromeActive, isTrue);
    expect(controller.nativeBottomInset, 178);
    expect(bridge.lastLayout, (true, true));

    useWideViewport();
    expect(controller.nativeChromeActive, isFalse);
    expect(controller.nativeBottomInset, 0);
    expect(bridge.lastLayout, (false, false));
    expect(find.text('charts'), findsOneWidget);

    useMobileShellViewport(controller);
    expect(controller.nativeChromeActive, isTrue);
    expect(bridge.lastLayout, (true, true));
    expect(find.text('charts'), findsOneWidget);
  });

  testWidgets('宽 iPad 先布局、native ready 后到也不显示底栏', (tester) async {
    useWideViewport();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/charts');
    await tester.pumpAndSettle();
    reportReady();
    await tester.pump();
    expect(controller.nativeChromeActive, isFalse);
    expect(bridge.lastLayout, (false, false));
    expect(bridge.lastTab, 'charts');
  });

  test('大字下发增高后的尺寸并展开 dock，随后滚动也不能收缩', () async {
    useMobileShellViewport(controller);
    reportReady();
    await pumpEventQueue();
    controller.reportScroll(minimized: true);
    controller.updateViewport(
      useBottomChrome: true,
      miniPlayerHeight: 79,
      miniTitleFontSize: 28,
      miniDetailFontSize: 24,
      allowMinimize: false,
    );
    controller.reportScroll(minimized: true);
    expect(bridge.lastMiniMetrics, (79, 28, 24));
    expect(bridge.lastAllowMinimize, isFalse);
    expect(bridge.scrollReports, <bool>[true, false]);
  });

  test('未装载本机 MediaItem 的恢复态可显示，同曲换输出更新且重复状态去重', () async {
    controller.attachAudioHandler(audio);
    await pumpEventQueue();
    const track = MediaItem(id: 'track-1', title: '测试曲目');
    expect(audio.mediaItem.value, isNull);
    controller.updateMetadata(track: track, outputLabel: '本机播放');
    expect(bridge.lastNowPlaying?.$1, 'track-1');
    final before = bridge.nowPlayingUpdates;
    controller.updateMetadata(track: track, outputLabel: '客厅音箱');
    expect(bridge.lastNowPlaying?.$1, 'track-1');
    expect(bridge.lastOutputLabel, '客厅音箱');
    expect(bridge.nowPlayingUpdates, before + 1);
    controller.updateMetadata(track: track, outputLabel: '客厅音箱');
    expect(bridge.nowPlayingUpdates, before + 1);

    audio.playbackState.add(PlaybackState(playing: true));
    await pumpEventQueue();
    expect(bridge.lastNowPlaying?.$5, isTrue);
    controller.updateMetadata(track: null, outputLabel: '客厅音箱');
    expect(bridge.lastNowPlaying?.$1, isNull);
  });

  testWidgets('输出 intent 只打开一层设备页，返回恢复外壳且不触发播放', (tester) async {
    useMobileShellViewport(controller);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/charts');
    await tester.pumpAndSettle();
    controller.handleIntent(
      const ShellIntent(ShellIntentType.openOutputPicker),
    );
    controller.handleIntent(
      const ShellIntent(ShellIntentType.openOutputPicker),
    );
    await tester.pumpAndSettle();
    expect(find.text('outputs'), findsOneWidget);
    expect(bridge.lastLayout, (false, false));
    expect(player.calls, isEmpty);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('charts'), findsOneWidget);
    expect(bridge.lastLayout, (true, true));
    expect(router.canPop(), isFalse);
  });

  testWidgets('统计页面保留路由，原生导航选中统计入口', (tester) async {
    useMobileShellViewport(controller);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/stats');
    await tester.pumpAndSettle();
    expect(find.text('stats'), findsOneWidget);
    expect(bridge.lastTab, 'stats');
    expect(bridge.lastTitle, '统计');
    expect(bridge.lastLayout, (true, true));
  });

  testWidgets('收起态搜索打开覆盖页，返回保留原入口且不触发播放', (tester) async {
    useMobileShellViewport(controller);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/charts');
    await tester.pumpAndSettle();
    controller.handleIntent(const ShellIntent(ShellIntentType.openSearch));
    await tester.pumpAndSettle();
    expect(find.text('search'), findsOneWidget);
    expect(bridge.lastLayout, (false, false));
    expect(player.calls, isEmpty);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('charts'), findsOneWidget);
    expect(bridge.lastLayout, (true, true));
  });
}
