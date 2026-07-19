import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/features/settings/widgets/settings_section_subpage.dart';

void main() {
  testWidgets('设置子页：系统返回与页头返回键都走 onBack 回菜单，不冒泡', (tester) async {
    var backCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsSectionSubpage(
            title: '小米账号',
            onBack: () => backCount++,
            child: const Text('内容'),
          ),
        ),
      ),
    );
    expect(find.text('小米账号'), findsOneWidget);

    // 系统返回被拦下转 onBack（返回 true = 不冒泡退 App）。
    expect(await tester.binding.handlePopRoute(), isTrue);
    expect(backCount, 1);

    // 页头返回键同一条路。
    await tester.tap(find.text('设置'));
    expect(backCount, 2);
  });
}
