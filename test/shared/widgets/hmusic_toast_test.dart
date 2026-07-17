import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_palette.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/shared/layout/shell_metrics.dart';
import 'package:hmusic/shared/models/hmusic_notice.dart';
import 'package:hmusic/shared/widgets/hmusic_toast.dart';

// docs/03 Toast 规格：无动画、3.2s 自动消失、内容自适应宽 ≤90%、语义左边框、
// 不挡点击；底距避让底部 chrome（桌面 = mini 包络 76 + 12，窄屏 = 悬浮玻璃
// chrome 完整包络：底距 + dock + gap + mini 胶囊 + 呼吸距）。

const String _msg = '已加入队列：海屿你';

late BuildContext _hostContext;
int _tapCount = 0;

Future<void> _pumpHost(
  WidgetTester tester, {
  Size size = const Size(1200, 800),
  ThemeData? theme,
}) async {
  _tapCount = 0;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? HMusicTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            _hostContext = context;
            // 铺满全屏的点击面，验证 toast 不拦截其下的手势。
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _tapCount++,
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    ),
  );
}

// toast 气泡容器：message 文本向上最近的 Container（带 panel 装饰）。
Finder _bubble() =>
    find.ancestor(of: find.text(_msg), matching: find.byType(Container)).first;

// 用例间清场：toast 挂在模块级单例上，避免前一个用例的 Timer 泄漏到下一个。
Future<void> _drain(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 4));

void main() {
  testWidgets('无动画立即出现，3.2s 后自动消失', (tester) async {
    await _pumpHost(tester);
    showHMusicToast(_hostContext, const HMusicNotice(_msg));
    // 单帧 pump 即完整可见 = 无入场动画。
    await tester.pump();
    expect(find.text(_msg), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3100));
    expect(find.text(_msg), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(_msg), findsNothing);
  });

  testWidgets('新 toast 顶替旧 toast', (tester) async {
    await _pumpHost(tester);
    showHMusicToast(_hostContext, const HMusicNotice('第一条'));
    await tester.pump();
    showHMusicToast(_hostContext, const HMusicNotice(_msg));
    await tester.pump();
    expect(find.text('第一条'), findsNothing);
    expect(find.text(_msg), findsOneWidget);
    await _drain(tester);
  });

  testWidgets('不拦截其下的点击', (tester) async {
    await _pumpHost(tester);
    showHMusicToast(_hostContext, const HMusicNotice(_msg));
    await tester.pump();
    await tester.tapAt(tester.getCenter(_bubble()));
    expect(_tapCount, 1);
    await _drain(tester);
  });

  testWidgets('桌面：居中于内容区、底部避开 mini player 包络', (tester) async {
    await _pumpHost(tester);
    showHMusicToast(_hostContext, const HMusicNotice(_msg));
    await tester.pump();

    final rect = tester.getRect(_bubble());
    expect(rect.bottom, 800.0 - (kMiniPlayerDesktopInset + 12));
    // 水平中点 = 侧栏右侧内容区的中点，而不是整窗中点。
    expect(
      rect.center.dx,
      moreOrLessEquals(kSidebarWidth + (1200 - kSidebarWidth) / 2, epsilon: 1),
    );
    await _drain(tester);
  });

  testWidgets('窄屏：让出悬浮 dock + mini 胶囊包络', (tester) async {
    await _pumpHost(tester, size: const Size(390, 844));
    showHMusicToast(_hostContext, const HMusicNotice(_msg));
    await tester.pump();

    final rect = tester.getRect(_bubble());
    // 无安全区（测试窗）：底距 10 + dock 66 + gap 8 + mini 50 + 呼吸距 8。
    expect(
      rect.bottom,
      844.0 -
          (chromeBottomOffset(0) +
              kChromeDockHeight +
              kChromeGap +
              kChromeMiniHeight +
              kChromeContentClearance),
    );
    expect(rect.center.dx, moreOrLessEquals(195, epsilon: 1));
    await _drain(tester);
  });

  testWidgets('长文案不超过内容区 90% 宽', (tester) async {
    await _pumpHost(tester, size: const Size(390, 844));
    showHMusicToast(_hostContext, HMusicNotice('超长提示' * 40));
    await tester.pump();

    final width = tester
        .getRect(
          find
              .ancestor(
                of: find.textContaining('超长提示'),
                matching: find.byType(Container),
              )
              .first,
        )
        .width;
    expect(width, lessThanOrEqualTo(390 * 0.9));
    await _drain(tester);
  });

  testWidgets('语义左边框：success 青绿 / info 灰', (tester) async {
    await _pumpHost(tester);
    showHMusicToast(_hostContext, const HMusicNotice.success(_msg));
    await tester.pump();
    var strip = tester.widget<ColoredBox>(
      find.descendant(of: _bubble(), matching: find.byType(ColoredBox)).last,
    );
    expect(strip.color, HMusicPalette.light.accent);

    showHMusicToast(_hostContext, const HMusicNotice(_msg));
    await tester.pump();
    strip = tester.widget<ColoredBox>(
      find.descendant(of: _bubble(), matching: find.byType(ColoredBox)).last,
    );
    expect(strip.color, HMusicPalette.light.mutedStrong);
    await _drain(tester);
  });

  testWidgets('暗色 error：panel 底、红字、红语义条', (tester) async {
    await _pumpHost(tester, theme: HMusicTheme.dark());
    showHMusicToast(_hostContext, const HMusicNotice.error(_msg));
    await tester.pump();

    final container = tester.widget<Container>(_bubble());
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, HMusicPalette.dark.panel);

    final text = tester.widget<Text>(find.text(_msg));
    expect(text.style?.color, HMusicPalette.dark.danger);

    final strip = tester.widget<ColoredBox>(
      find.descendant(of: _bubble(), matching: find.byType(ColoredBox)).last,
    );
    expect(strip.color, HMusicPalette.dark.danger);
    await _drain(tester);
  });
}
