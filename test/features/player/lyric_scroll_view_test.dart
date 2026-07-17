import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/features/player/models/hmusic_lyric.dart';
import 'package:hmusic/features/player/view_models/lyric_view_model.dart';
import 'package:hmusic/features/player/widgets/lyric_scroll_view.dart';

// 预置歌词的假 VM：跳过 ensureLyric → 网络层，直接给行数据。
class _StubLyricViewModel extends LyricViewModel {
  _StubLyricViewModel(this._preset);

  final LyricState _preset;

  @override
  LyricState build() => _preset;
}

const int _lineCount = 40;

LyricState _fortyLines() => LyricState(
  lyric: HMusicLyric(
    lines: List<LyricLine>.generate(
      _lineCount,
      (i) => LyricLine(timeMs: i * 1000, text: '这是第 $i 行歌词'),
    ),
  ),
);

Future<void> _pump(WidgetTester tester, int activeLine, {LyricState? state}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        lyricViewModelProvider.overrideWith(
          () => _StubLyricViewModel(state ?? _fortyLines()),
        ),
      ],
      child: MaterialApp(
        theme: HMusicTheme.light(),
        home: Scaffold(
          body: LyricScrollView(
            activeLine: activeLine,
            seekEnabled: false,
            onLineTap: (_) {},
          ),
        ),
      ),
    ),
  );
}

// 当前行顶边在视口内的对齐系数：ensureVisible(alignment: a) 的落点满足
// rowTop = a * (viewportH - rowH)，反解出 a 与 0.4 比对。
double _anchorRatio(WidgetTester tester, int line) {
  final viewport = tester.getRect(find.byType(LyricScrollView));
  final row = tester.getRect(
    find
        .ancestor(
          of: find.text('这是第 $line 行歌词'),
          matching: find.byType(InkWell),
        )
        .first,
  );
  return (row.top - viewport.top) / (viewport.height - row.height);
}

void main() {
  setUp(() {
    // 固定视口，几何断言可复算。
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> host(WidgetTester tester, int activeLine) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, activeLine);
    await tester.pumpAndSettle();
  }

  testWidgets('进页即定位：当前行落在视口中线略偏上（0.4）', (tester) async {
    await host(tester, 20);
    expect(_anchorRatio(tester, 20), moreOrLessEquals(0.4, epsilon: 0.03));
  });

  testWidgets('行推进跟随：近跳与远跳都不累积漂移', (tester) async {
    await host(tester, 0);
    // 近跳（相邻行已物化，走真实几何动画路径）。
    await _pump(tester, 1);
    await tester.pumpAndSettle();
    expect(_anchorRatio(tester, 1), moreOrLessEquals(0.4, epsilon: 0.03));
    // 远跳（目标行未物化，走估算粗跳 + 下一帧校正路径）。
    await _pump(tester, 35);
    await tester.pumpAndSettle();
    expect(_anchorRatio(tester, 35), moreOrLessEquals(0.4, epsilon: 0.03));
    // 旧实现按 52 估行高，此处会漂出 ~200px 钉在视口顶部。
    await _pump(tester, 36);
    await tester.pumpAndSettle();
    expect(_anchorRatio(tester, 36), moreOrLessEquals(0.4, epsilon: 0.03));
  });

  testWidgets('首尾行也停在锚点：padding 随视口等比预留', (tester) async {
    await host(tester, 0);
    expect(_anchorRatio(tester, 0), moreOrLessEquals(0.4, epsilon: 0.03));
    await _pump(tester, _lineCount - 1);
    await tester.pumpAndSettle();
    expect(
      _anchorRatio(tester, _lineCount - 1),
      moreOrLessEquals(0.4, epsilon: 0.03),
    );
  });

  testWidgets('整段降级展示剥掉 [标签]，不裸露时间戳', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      -1,
      state: const LyricState(
        lyric: HMusicLyric(lrc: '[00:00:00]整段歌词正文\n[ti:标题标签]'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('整段歌词正文'), findsOneWidget);
    expect(find.textContaining('[00:00:00]'), findsNothing);
  });
}
