import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/shared/widgets/pressable_scale.dart';

// 取当前实际渲染的缩放倍率：读 Transform 矩阵的 x 分量，
// 比读 widget 参数可靠（后者是目标值，不是当帧值）。
double _scaleOf(WidgetTester tester, [Finder? scope]) {
  final transform = tester
      .widgetList<Transform>(
        find.descendant(
          of: scope ?? find.byType(PressableScale),
          matching: find.byType(Transform),
        ),
      )
      .first;
  return transform.transform.storage[0];
}

// 推进到按压动画静止。分多帧而非单帧 200ms：滚动容器内 GestureDetector 要先与
// 竖向拖拽竞技（实测 ~100ms 才发 onTapDown），单帧推进会在动画还没起步时就取值。
// 不用 pumpAndSettle——手势未松开时它会因动画未结束而超时。
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('按下缩到 0.97，松手回弹 1.0', (tester) async {
    await tester.pumpWidget(
      _host(
        PressableScale(
          onTap: () {},
          child: const SizedBox(width: 100, height: 40),
        ),
      ),
    );
    expect(_scaleOf(tester), 1.0);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await _settle(tester);
    expect(_scaleOf(tester), closeTo(0.97, 0.001));

    await gesture.up();
    await _settle(tester);
    expect(_scaleOf(tester), 1.0);
  });

  testWidgets('滚动中划走：tapCancel 立即回弹，不卡在缩小态', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              for (int i = 0; i < 20; i++)
                PressableScale(
                  onTap: () {},
                  child: SizedBox(height: 60, child: Text('行 $i')),
                ),
            ],
          ),
        ),
      ),
    );

    final row = find.ancestor(
      of: find.text('行 1'),
      matching: find.byType(PressableScale),
    );
    final gesture = await tester.startGesture(tester.getCenter(row));
    await _settle(tester);
    // 先确认真的缩下去了，否则「回弹到 1.0」是起点值假通过。
    expect(_scaleOf(tester, row), closeTo(0.97, 0.001));

    // 手指竖向移动足够距离 → 手势判给 ListView 拖拽，PressableScale 收 tapCancel。
    await gesture.moveBy(const Offset(0, -80));
    await _settle(tester);
    expect(_scaleOf(tester, row), 1.0);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('减动效环境：时长归零，按下即到位', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: PressableScale(
                onTap: () {},
                child: const SizedBox(width: 100, height: 40),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    // 只推一帧、不给时长：duration 归零时首帧就该到位。
    await tester.pump();
    expect(_scaleOf(tester), closeTo(0.97, 0.001));

    await gesture.up();
    await tester.pump();
    expect(_scaleOf(tester), 1.0);
  });

  testWidgets('onTap 为 null：不接手势，无缩放包装', (tester) async {
    await tester.pumpWidget(
      _host(const PressableScale(child: SizedBox(width: 100, height: 40))),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PressableScale)),
    );
    await _settle(tester);
    expect(_scaleOf(tester), 1.0);
    await gesture.up();
  });
}
