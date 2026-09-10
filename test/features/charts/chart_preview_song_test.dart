import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/features/charts/models/chart.dart';
import 'package:hmusic/features/charts/widgets/chart_preview_song.dart';

void main() {
  for (final enabled in <bool>[true, false]) {
    testWidgets('榜单预览 ${enabled ? '可播放' : '不可播放'} 时读屏与触控动作一致', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var plays = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  child: ChartPreviewSong(
                    entry: const ChartEntry(
                      rank: 1,
                      title: '稻香',
                      artist: '周杰伦',
                    ),
                    onTap: enabled ? () => plays++ : null,
                  ),
                ),
              ),
            ),
          ),
        );
        final node = tester.getSemantics(find.bySemanticsLabel('稻香，周杰伦'));
        final data = node.getSemanticsData();
        expect(data.label, '稻香，周杰伦');
        expect(data.hasAction(SemanticsAction.tap), enabled);
        expect(data.flagsCollection.isButton, enabled);
        final owner = tester
            .renderObject(find.byType(ChartPreviewSong))
            .owner!
            .semanticsOwner!;
        owner.performAction(node.id, SemanticsAction.tap);
        await tester.pump();
        expect(plays, enabled ? 1 : 0);
        await tester.tap(find.text('稻香'));
        await tester.pumpAndSettle();
        expect(plays, enabled ? 2 : 0);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}
