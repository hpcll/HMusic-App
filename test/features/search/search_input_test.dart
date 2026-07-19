import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/features/search/widgets/search_input.dart';

// Apple Music 式搜索框：灰底胶囊、放大镜前缀、无独立搜索按钮；
// 键盘搜索键提交，搜索中不重复提交。
void main() {
  late int searches;
  late TextEditingController controller;

  setUp(() {
    searches = 0;
    controller = TextEditingController();
  });
  tearDown(() => controller.dispose());

  Future<void> pumpInput(
    WidgetTester tester, {
    required bool isSearching,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HMusicTheme.light(),
        home: Scaffold(
          body: SearchInput(
            controller: controller,
            isSearching: isSearching,
            onSearch: () => searches++,
          ),
        ),
      ),
    );
  }

  testWidgets('无独立搜索按钮，键盘搜索键提交', (tester) async {
    await pumpInput(tester, isSearching: false);

    expect(find.byType(FilledButton), findsNothing);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), '周杰伦');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(searches, 1);
  });

  testWidgets('搜索中挡重复提交', (tester) async {
    await pumpInput(tester, isSearching: true);

    await tester.enterText(find.byType(TextField), '周杰伦');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(searches, 0);
  });
}
