import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/features/player/widgets/mini_player_track_info.dart';

import 'support/playback_ui_fixture.dart';

void main() {
  testWidgets('mini 曲目信息可通过读屏打开播放器', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final fixture = PlaybackUiFixture();
      addTearDown(fixture.handler.disposeHandler);
      var playerOpens = 0;
      await fixture.pump(
        tester,
        Center(
          child: SizedBox(
            width: 200,
            child: MiniPlayerTrackInfo(
              state: uiPlayback(),
              onOpenPlayer: () => playerOpens++,
            ),
          ),
        ),
        size: const Size(360, 800),
      );

      final track = tester.getSemantics(
        find.bySemanticsLabel('${uiTrack.title}，${uiTrack.artist}，打开播放器'),
      );
      expect(track.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      final owner = tester
          .renderObject(find.byType(MiniPlayerTrackInfo))
          .owner!
          .semanticsOwner!;
      owner.performAction(track.id, SemanticsAction.tap);
      await tester.pump();
      expect(playerOpens, 1);

      expect(fixture.controller.calls, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
