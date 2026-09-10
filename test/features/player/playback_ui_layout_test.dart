import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/audio/models/hmusic_playback_state.dart';
import 'package:hmusic/features/player/views/player_page.dart';
import 'package:hmusic/features/player/widgets/desktop_playback_bar.dart';
import 'package:hmusic/features/player/widgets/mini_player.dart';
import 'package:hmusic/features/player/widgets/player_output_button.dart';
import 'package:hmusic/features/player/widgets/player_seek_bar.dart';
import 'package:hmusic/features/player/widgets/player_target_volume.dart';
import 'package:hmusic/shared/layout/shell_metrics.dart';

import 'support/playback_ui_fixture.dart';

void main() {
  for (final viewport in [900.0, 1120.0, 1280.0, 1920.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('桌面 $viewport / $scale 倍字：核心控制完整且高度等于壳占位', (tester) async {
        final fixture = PlaybackUiFixture();
        addTearDown(fixture.handler.disposeHandler);
        final width = viewport - shellNavigationWidth(viewport);
        await fixture.pump(
          tester,
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(width: width, child: const DesktopPlaybackBar()),
          ),
          size: Size(viewport, 600),
          scale: scale,
          dark: scale == 2,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(PlayerSeekBar), findsOneWidget);
        expect(find.byType(PlayerTargetVolume), findsOneWidget);
        expect(find.byType(PlayerOutputButton), findsOneWidget);
        expect(find.byTooltip('上一首'), findsOneWidget);
        expect(find.byTooltip('下一首'), findsOneWidget);
        expect(find.byTooltip('播放队列（8）'), findsOneWidget);
        expect(
          tester.getSize(find.byType(DesktopPlaybackBar)).height,
          desktopPlaybackBarHeight(
            contentWidth: width,
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.tap(find.byTooltip('下一首'));
        expect(fixture.controller.calls, ['next']);
      });
    }
  }

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('360 手机 mini / $scale 倍字：两行无溢出，切歌不误开播放器', (tester) async {
      final fixture = PlaybackUiFixture();
      addTearDown(fixture.handler.disposeHandler);
      await fixture.pump(
        tester,
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: MiniPlayer(capsule: true),
          ),
        ),
        size: const Size(360, 800),
        scale: scale,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(uiTrack.title), findsOneWidget);
      expect(find.text(uiTrack.artist), findsOneWidget);
      expect(find.byType(PlayerOutputButton), findsNothing);
      expect(
        tester.getSize(find.byType(MiniPlayer)).height,
        mobileMiniPlayerHeight(TextScaler.linear(scale)),
      );
      final next = find.byTooltip('下一首');
      expect(tester.getSize(next).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(next).height, greaterThanOrEqualTo(44));
      // 此测试未挂 GoRouter；若播控点击冒泡到打开播放器，会直接产生异常。
      await tester.tap(next);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(fixture.controller.calls, ['next']);
    });
  }

  for (final size in [const Size(844, 390), const Size(360, 640)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('完整播放器 $size / $scale 倍字：播控和音量可滚动到达', (tester) async {
        final fixture = PlaybackUiFixture();
        addTearDown(fixture.handler.disposeHandler);
        await fixture.pump(
          tester,
          const PlayerPage(),
          size: size,
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        final output = find.byType(PlayerOutputButton);
        await tester.ensureVisible(output);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(output.hitTestable(), findsOneWidget);
        expect(find.byType(PlayerTargetVolume).hitTestable(), findsOneWidget);
      });
    }
  }

  testWidgets('清空曲目后 mini 保留未在播放，禁用播放且不显示加载圈', (tester) async {
    final fixture = PlaybackUiFixture();
    addTearDown(fixture.handler.disposeHandler);
    await fixture.pump(
      tester,
      const MiniPlayer(capsule: true),
      size: const Size(360, 800),
    );
    fixture.handler.emit(
      HMusicPlaybackState.fromJson({
        ...uiPlayback().toJson(),
        'track': null,
        'state': 'idle',
        'queueLength': 0,
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('未在播放'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.play_arrow_rounded),
          )
          .onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
