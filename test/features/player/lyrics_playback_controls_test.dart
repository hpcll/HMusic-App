import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/features/player/view_models/player_view_model.dart';
import 'package:hmusic/features/player/widgets/lyrics_mini_controls.dart';

import 'support/playback_ui_fixture.dart';

void main() {
  testWidgets('歌词播控初始化时保留按钮占位和加载反馈', (tester) async {
    final fixture = PlaybackUiFixture();
    final controls = StreamController<PlaybackState>();
    addTearDown(fixture.handler.disposeHandler);
    addTearDown(controls.close);
    await fixture.pump(
      tester,
      ProviderScope(
        overrides: [
          playbackControlsStateProvider.overrideWith((ref) => controls.stream),
        ],
        child: LyricsMiniControls(state: uiPlayback()),
      ),
      size: const Size(360, 640),
    );
    expect(find.byTooltip('上一首'), findsOneWidget);
    expect(find.byTooltip('下一首'), findsOneWidget);
    expect(find.byTooltip('正在加载'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(360, 640), const Size(844, 390)]) {
    testWidgets('歌词页 $size 主播放键清晰且可点击', (tester) async {
      final fixture = PlaybackUiFixture();
      addTearDown(fixture.handler.disposeHandler);
      await fixture.pump(
        tester,
        LyricsMiniControls(state: uiPlayback()),
        size: size,
        scale: 2,
      );
      final pause = find.byTooltip('暂停');
      expect(pause.hitTestable(), findsOneWidget);
      expect(tester.getSize(pause).shortestSide, greaterThanOrEqualTo(56));
      await tester.tap(pause);
      expect(fixture.controller.calls, ['pause']);
      expect(tester.takeException(), isNull);
    });
  }
}
