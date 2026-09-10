import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/shell/bottom_nav.dart';
import 'package:hmusic/features/player/widgets/mini_player.dart';
import 'package:hmusic/shared/layout/shell_metrics.dart';

import 'support/chrome_fixture.dart';
import 'support/chrome_visual_capture.dart';

void main() {
  registerChromeVisualCaptures();
  for (final (width, branch, icon) in [
    (320.0, 4, Icons.local_fire_department_rounded),
    (360.0, 6, Icons.settings_rounded),
    (430.0, 5, Icons.insights_rounded),
  ]) {
    testWidgets('$width 窄屏：细 mini 连续收成左导航、中播放、右搜索', (tester) async {
      final fixture = PlaybackUiFixture();
      final router = await pumpChrome(
        tester,
        fixture,
        width: width,
        initialBranch: branch,
      );
      final mini = find.byType(MiniPlayer);
      final dock = find.byType(AppBottomNav);
      final expanded = tester.getRect(mini);
      expect(expanded.height, 50);
      expect(expanded.bottom, lessThan(tester.getRect(dock).top));
      final gesture = await beginChromeScroll(tester);
      var previous = expanded;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final rect = tester.getRect(mini);
        expect(rect.top, greaterThanOrEqualTo(previous.top - 0.01));
        expect(rect.width, lessThanOrEqualTo(previous.width + 0.01));
        expect(rect.center.dx, closeTo(width / 2, 0.01));
        expect(rect.height, 50);
        expect(tester.takeException(), isNull);
        previous = rect;
      }
      await gesture.up();
      await tester.pumpAndSettle();

      final compact = tester.getRect(mini);
      final nav = tester.getRect(dock);
      final search = tester.getRect(find.byTooltip('搜索'));
      expect(nav.width, nav.height);
      expect(nav.right + kChromeGap, compact.left);
      expect(compact.right + kChromeGap, search.left);
      expect(nav.bottom, compact.bottom);
      expect(search.bottom, compact.bottom);
      expect(compact.bottom, lessThan(844 - 16));
      expect(find.text(uiTrack.artist), findsNothing);
      expect(find.byTooltip('下一首'), findsNothing);
      expect(tester.getSize(find.byTooltip('暂停')), const Size(44, 44));
      await tester.tap(find.byTooltip('暂停'));
      expect(fixture.controller.calls, ['pause']);
      await tester.tap(find.byTooltip('搜索'));
      await tester.pumpAndSettle();
      expect(find.text('overlay-/search'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      expect(tester.getRect(mini), expanded);
      expect(router.routeInformationProvider.value.uri.path, '/b$branch');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('动画中途反向滚动从当前形状展开，不跳回端点', (tester) async {
    await pumpChrome(tester, PlaybackUiFixture());
    final mini = find.byType(MiniPlayer);
    final expanded = tester.getRect(mini);
    final gesture = await beginChromeScroll(tester);
    await tester.pump(const Duration(milliseconds: 80));
    final middle = tester.getRect(mini);
    expect(middle.width, lessThan(expanded.width));
    expect(middle.width, greaterThan(390 - 32 - 116));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(tester.getRect(mini), middle);
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getRect(mini).width, greaterThan(middle.width));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(mini), expanded);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无曲目时两种布局都保留 mini，点击空闲播控不发送命令', (tester) async {
    final fixture = PlaybackUiFixture(state: idlePlayback());
    await pumpChrome(tester, fixture);
    expect(find.text('未在播放'), findsOneWidget);
    final gesture = await beginChromeScroll(tester);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('未在播放'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.play_arrow_rounded),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('播放'));
    expect(fixture.controller.calls, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byTooltip('搜索').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.5, 2.0]) {
    testWidgets('$scale 倍字保持展开，曲名与播控不被收缩挤压', (tester) async {
      await pumpChrome(tester, PlaybackUiFixture(), width: 360, scale: scale);
      final gesture = await beginChromeScroll(tester);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppBottomNav>(find.byType(AppBottomNav)).progress,
        0,
      );
      expect(find.text(uiTrack.artist), findsOneWidget);
      expect(find.byTooltip('下一首').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('减动效立即切换，两个方向都无待完成的形变', (tester) async {
    await pumpChrome(tester, PlaybackUiFixture(), reduceMotion: true);
    final gesture = await beginChromeScroll(tester);
    expect(tester.widget<AppBottomNav>(find.byType(AppBottomNav)).progress, 1);
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(tester.widget<AppBottomNav>(find.byType(AppBottomNav)).progress, 0);
    await gesture.up();
    expect(tester.takeException(), isNull);
  });
}
