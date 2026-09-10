import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/core/models/hmusic_track.dart';
import 'package:hmusic/shared/widgets/hmusic_adaptive_track_row.dart';
import 'package:hmusic/shared/widgets/hmusic_confirm_button.dart';
import 'package:hmusic/shared/widgets/hmusic_icon_button.dart';
import 'package:hmusic/shared/widgets/hmusic_track_row.dart';
import 'package:hmusic/shared/widgets/hmusic_track_table_header.dart';

const _track = HMusicTrack(
  id: 'wy:long',
  source: 'wy',
  sourceTrackId: 'long',
  title: '一首标题很长很长的歌曲名称用于验证剩余列宽',
  artist: '一位名字很长的歌手',
  album: '一张名称很长的专辑',
  durationMs: 242000,
);

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  HMusicTrack track = _track,
  VoidCallback? onPlay,
  Future<bool> Function()? onEnqueue,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1600, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? HMusicTheme.dark()
          : HMusicTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(1600, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: Column(
                children: <Widget>[
                  const HMusicTrackTableHeader(actionsWidth: 94),
                  HMusicAdaptiveTrackRow(
                    track: track,
                    actionsWidth: 94,
                    onTap: onPlay,
                    actions: <Widget>[
                      const HMusicIconButton(
                        icon: Icons.download_rounded,
                        tooltip: '下载到服务器',
                        onPressed: null,
                      ),
                      HMusicConfirmButton(
                        icon: Icons.add_rounded,
                        tooltip: '加入队列',
                        onAction: onEnqueue ?? () async => true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in <double>[320, 640, 720, 900, 1280]) {
    for (final scale in <double>[1, 2]) {
      testWidgets('实际宽 $width、字号 $scale：长曲名与两枚操作不溢出', (tester) async {
        await _pump(tester, width: width, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(HMusicAdaptiveTrackRow)).width,
          width,
        );
        expect(find.byTooltip('加入队列'), findsOneWidget);
      });
    }
  }

  testWidgets('宽视口内的窄列表使用两行，宽列表才分列并展示真实时长', (tester) async {
    await _pump(tester, width: 400);
    expect(find.byType(HMusicTrackRow), findsOneWidget);
    expect(find.text('时长'), findsNothing);
    await _pump(tester, width: 1280);
    expect(find.byType(HMusicTrackRow), findsNothing);
    expect(find.text('时长'), findsOneWidget);
    expect(find.text('4:02'), findsOneWidget);
    expect(find.text('网易云'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(_track.artist)).dx,
      greaterThan(tester.getTopLeft(find.text(_track.title)).dx),
    );
  });

  testWidgets('行尾加入队列只发一次动作，不触发行播放，原地确认保留', (tester) async {
    var plays = 0;
    var enqueues = 0;
    await _pump(
      tester,
      width: 1000,
      brightness: Brightness.dark,
      onPlay: () => plays++,
      onEnqueue: () async {
        enqueues++;
        return true;
      },
    );
    await tester.tap(find.byTooltip('加入队列'));
    await tester.pumpAndSettle();
    expect(enqueues, 1);
    expect(plays, 0);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.text(_track.title));
    expect(plays, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('缺失专辑和时长使用占位，不虚构元数据', (tester) async {
    await _pump(
      tester,
      width: 1000,
      track: const HMusicTrack(
        id: 'local:unknown',
        source: 'local',
        sourceTrackId: 'unknown',
        title: '没有完整标签的音频',
        artist: '',
      ),
    );
    expect(find.text('未知歌手'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(2));
    expect(find.text('0:00'), findsNothing);
  });
}
