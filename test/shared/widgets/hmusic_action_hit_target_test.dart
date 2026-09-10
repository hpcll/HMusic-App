import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/shared/widgets/hmusic_confirm_button.dart';
import 'package:hmusic/shared/widgets/hmusic_icon_button.dart';

Future<void> _mount(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: HMusicTheme.light(),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('图标按钮的透明外圈也能点击', (tester) async {
    var calls = 0;
    await _mount(
      tester,
      HMusicIconButton(
        icon: Icons.add,
        tooltip: '加入队列',
        onPressed: () => calls++,
      ),
    );
    final rect = tester.getRect(find.byType(HMusicIconButton));
    expect(rect.width, greaterThanOrEqualTo(44));
    for (final point in <Offset>[
      rect.centerLeft + const Offset(1, 0),
      rect.centerRight - const Offset(1, 0),
      rect.topCenter + const Offset(0, 1),
      rect.bottomCenter - const Offset(0, 1),
    ]) {
      await tester.tapAt(point);
      await tester.pump();
    }
    expect(calls, 4);
    expect(find.byTooltip('加入队列'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('禁用图标按钮的中心和外圈都不发送操作', (tester) async {
    await _mount(
      tester,
      const HMusicIconButton(
        icon: Icons.download_done,
        tooltip: '已保存到服务器',
        onPressed: null,
      ),
    );
    final rect = tester.getRect(find.byType(HMusicIconButton));
    await tester.tapAt(rect.center);
    await tester.tapAt(rect.centerLeft + const Offset(1, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('已保存到服务器'), findsOneWidget);
  });

  testWidgets('确认按钮外圈可点击，处理中和确认后不重复提交', (tester) async {
    var calls = 0;
    final completion = Completer<bool>();
    await _mount(
      tester,
      HMusicConfirmButton(
        icon: Icons.add,
        tooltip: '加入队列',
        onAction: () {
          calls++;
          return completion.future;
        },
      ),
    );
    final rect = tester.getRect(find.byType(HMusicConfirmButton));
    final outerPoint = rect.centerLeft + const Offset(1, 0);
    await tester.tapAt(outerPoint);
    await tester.pump();
    expect(calls, 1);
    await tester.tapAt(rect.center);
    await tester.tapAt(outerPoint);
    await tester.pump();
    expect(calls, 1);

    completion.complete(true);
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tapAt(rect.center);
    await tester.pump();
    expect(calls, 1);
    expect(find.byTooltip('加入队列'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1601));
    await tester.tapAt(outerPoint);
    await tester.pump();
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
