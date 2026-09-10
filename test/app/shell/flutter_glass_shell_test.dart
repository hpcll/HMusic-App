import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/shell/flutter_glass_shell.dart';

// ScrollMinimizeListener 触发语义（原生壳与回退壳共用）：向下滚（内容上滑）
// 收缩，向上滚展开（UIKit onScrollDown），横滑不影响底栏。
void main() {
  late List<bool> signals;

  Future<void> pumpList(WidgetTester tester) async {
    signals = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScrollMinimizeListener(
            onMinimized: signals.add,
            child: ListView.builder(
              itemCount: 60,
              itemBuilder: (context, index) =>
                  SizedBox(height: 48, child: Text('row-$index')),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('向下滚收缩，向上滚立即展开，无需回到顶部', (tester) async {
    await pumpList(tester);

    // 内容上滑（向下滚）→ 收缩。
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(signals, isNotEmpty);
    expect(signals.last, isTrue);

    // 中途向上滚一段（未到顶）→ 展开。
    signals.clear();
    await tester.drag(find.byType(ListView), const Offset(0, 150));
    await tester.pumpAndSettle();
    expect(signals.last, isFalse);

    // 继续向上滚回到顶部 → 展开。
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(signals.last, isFalse);
  });

  testWidgets('横向滚动不影响 chrome 收缩状态', (tester) async {
    signals = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScrollMinimizeListener(
            onMinimized: signals.add,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 30,
              itemBuilder: (context, index) =>
                  SizedBox(width: 120, child: Text('col-$index')),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(signals, isEmpty);
  });
}
