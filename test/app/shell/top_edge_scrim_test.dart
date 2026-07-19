import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/shell/top_edge_scrim.dart';

// 顶部滚动消融（无常驻顶栏，对齐 Apple Music）：玻璃档 = 单层 shader 逐像素
// 渐进模糊（Impeller）+ 无拐点连续纱帘；后端不支持 shader 时退纯纱帘，
// 同样零缝；off 档（高对比）退回不透明渐变；任何档位都不拦截点击。
void main() {
  const safeTop = 44.0;

  Future<void> pumpScrim(
    WidgetTester tester, {
    bool highContrast = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            padding: const EdgeInsets.only(top: safeTop),
            highContrast: highContrast,
          ),
          child: const Scaffold(
            body: Align(alignment: Alignment.topCenter, child: TopEdgeScrim()),
          ),
        ),
      ),
    );
  }

  testWidgets('玻璃档：单层 shader 渐进模糊，后端不支持则退纯纱帘；总高 = 安全区 + 44', (tester) async {
    await pumpScrim(tester);
    // 支持 shader 的后端有一次异步编译；不支持时无任何挂起任务。
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(TopEdgeScrim),
        matching: find.byType(BackdropFilter),
      ),
      ui.ImageFilter.isShaderFilterSupported ? findsOneWidget : findsNothing,
    );
    expect(tester.getSize(find.byType(TopEdgeScrim)).height, safeTop + 44);

    // tint 是连续缓落曲线：首尾之外不存在两个相邻同值 stop（无恒定段拐点）。
    final tintBox = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(TopEdgeScrim),
            matching: find.byType(DecoratedBox),
          ),
        )
        .last;
    final gradient =
        (tintBox.decoration as BoxDecoration).gradient! as LinearGradient;
    for (var i = 1; i < gradient.colors.length; i++) {
      expect(
        gradient.colors[i].a,
        lessThan(gradient.colors[i - 1].a),
        reason: 'tint 必须单调连续衰减，不允许恒定段',
      );
    }
    expect(gradient.colors.last.a, 0);
  });

  testWidgets('off 档（高对比）：退回不透明渐变，无 backdrop 模糊', (tester) async {
    await pumpScrim(tester, highContrast: true);

    expect(find.byType(BackdropFilter), findsNothing);
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(TopEdgeScrim),
        matching: find.byType(DecoratedBox),
      ),
    );
    final gradient =
        (box.decoration as BoxDecoration).gradient! as LinearGradient;
    final background = Theme.of(
      tester.element(find.byType(TopEdgeScrim)),
    ).scaffoldBackgroundColor;
    expect(gradient.colors.first, background);
    expect(gradient.colors.last.a, 0);
    expect(tester.getSize(find.byType(TopEdgeScrim)).height, safeTop + 16);
  });

  testWidgets('不拦截其下的点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                ),
              ),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TopEdgeScrim(),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(200, 4));
    expect(taps, 1);
  });
}
