import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/features/player/widgets/cover_swipe_area.dart';

void main() {
  late int nextCount;
  late int previousCount;

  Widget harness() => MaterialApp(
    home: Center(
      child: CoverSwipeArea(
        onNext: () => nextCount++,
        onPrevious: () => previousCount++,
        child: const SizedBox.square(dimension: 300),
      ),
    ),
  );

  setUp(() {
    nextCount = 0;
    previousCount = 0;
  });

  testWidgets('左滑超过 60px：触发下一首', (tester) async {
    await tester.pumpWidget(harness());

    await tester.drag(find.byType(CoverSwipeArea), const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(nextCount, 1);
    expect(previousCount, 0);
  });

  testWidgets('右滑超过 60px：触发上一首', (tester) async {
    await tester.pumpWidget(harness());

    await tester.drag(find.byType(CoverSwipeArea), const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(previousCount, 1);
    expect(nextCount, 0);
  });

  testWidgets('位移不足阈值：不切歌且回弹', (tester) async {
    await tester.pumpWidget(harness());

    await tester.drag(find.byType(CoverSwipeArea), const Offset(-30, 0));
    await tester.pumpAndSettle();

    expect(nextCount, 0);
    expect(previousCount, 0);
  });
}
