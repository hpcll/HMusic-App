import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_palette.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/core/platform_shell/widgets/adaptive_glass_surface.dart';
import 'package:hmusic/shared/layout/shell_metrics.dart';
import 'package:hmusic/shared/models/hmusic_notice.dart';
import 'package:hmusic/shared/widgets/hmusic_toast.dart';

// docs/03 Toast 规格，Apple Music 式胶囊：180ms 淡入 + 上浮、3.2s 后 140ms
// 淡出、内容自适应宽 ≤90%、胶囊形态（高度 / 2 圆角）+ 毛玻璃、无 hairline、
// 语义 leading 图标（✓ 青绿 / ⚠ 红 / info 无）、文字恒墨色、不挡点击；
// 底距避让底部 chrome（桌面 = mini 包络 76 + 12，窄屏 = 悬浮玻璃 chrome 完整包络）。

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

// toast 胶囊容器：message 文本向上最近的 AdaptiveGlassSurface。
// 长文案测试不用固定 _msg，传入 textFinder 动态查找。
Finder _capsule([Finder? textFinder]) {
  final anchor = textFinder ?? find.text(_msg);
  return find
      .ancestor(of: anchor, matching: find.byType(AdaptiveGlassSurface))
      .first;
}

Finder _capsuleIcon() =>
    find.descendant(of: _capsule(), matching: find.byType(Icon));

// 用例间清场：toast 挂在模块级单例上，pumpAndSettle 走完淡出动画与移除，
// 避免前一个用例的 Timer/Ticker 泄漏到下一个。
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

// 挂载帧建立 ticker 基线后再推进 200ms，让 180ms 入场动画走完。
Future<void> _pumpEntrance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('180ms 淡入出现，3.2s 后淡出消失', (tester) async {
    await _pumpHost(tester);
    showHMusicToast(_hostContext, const HMusicNotice(_msg));
    await tester.pump();
    expect(find.text(_msg), findsOneWidget);

    // 入场完成后完全可见。
    await tester.pump(const Duration(milliseconds: 200));
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text(_msg), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 1.0);

    // 3.2s 前仍在；触发自动消失后走完淡出即移除。
    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.text(_msg), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
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
    await _pumpEntrance(tester);
    await tester.tapAt(tester.getCenter(_capsule()));
    expect(_tapCount, 1);
    await _drain(tester);
  });

  testWidgets('桌面：居中于内容区、底部避开 mini player 包络', (tester) async {
    await _pumpHost(tester);
    showHMusicToast(_hostContext, const HMusicNotice(_msg));
    await _pumpEntrance(tester);

    final rect = tester.getRect(_capsule());
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
    await _pumpEntrance(tester);

    final rect = tester.getRect(_capsule());
    // 无安全区（测试窗）：底距 + dock 66 + gap 8 + mini 50 + 呼吸距 8。底距按
    // 平台算（Android 让开整条手势条安全区，iOS 减 10），这里跟着主题平台走。
    expect(
      rect.bottom,
      844.0 -
          (chromeBottomOffset(0, platform: defaultTargetPlatform) +
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
    await _pumpEntrance(tester);

    final width = tester.getRect(_capsule(find.textContaining('超长提示'))).width;
    expect(width, lessThanOrEqualTo(390 * 0.9));
    await _drain(tester);
  });

  testWidgets('语义图标：success ✓ 青绿 / error ⚠ 红 / info 无图标', (tester) async {
    await _pumpHost(tester);
    showHMusicToast(_hostContext, const HMusicNotice.success(_msg));
    await _pumpEntrance(tester);
    var icon = tester.widget<Icon>(_capsuleIcon());
    expect(icon.icon, Icons.check_rounded);
    expect(icon.color, HMusicPalette.light.accent);

    showHMusicToast(_hostContext, const HMusicNotice.error(_msg));
    await _pumpEntrance(tester);
    icon = tester.widget<Icon>(_capsuleIcon());
    expect(icon.icon, Icons.error_outline_rounded);
    expect(icon.color, HMusicPalette.light.danger);

    showHMusicToast(_hostContext, const HMusicNotice(_msg));
    await _pumpEntrance(tester);
    expect(_capsuleIcon(), findsNothing);
    await _drain(tester);
  });

  testWidgets('暗色 error：毛玻璃底 + 墨色文字 + 无 hairline', (tester) async {
    await _pumpHost(tester, theme: HMusicTheme.dark());
    showHMusicToast(_hostContext, const HMusicNotice.error(_msg));
    await _pumpEntrance(tester);

    final glass = tester.widget<AdaptiveGlassSurface>(_capsule());
    expect(glass.hairline, isFalse);

    // 语义由图标承担，文字不再整句变红。
    final text = tester.widget<Text>(find.text(_msg));
    expect(text.style?.color, HMusicPalette.dark.textStrong);
    final icon = tester.widget<Icon>(_capsuleIcon());
    expect(icon.color, HMusicPalette.dark.danger);
    await _drain(tester);
  });

  testWidgets('胶囊形态：圆角 ≈ 高度 / 2', (tester) async {
    await _pumpHost(tester);
    showHMusicToast(_hostContext, const HMusicNotice(_msg));
    await _pumpEntrance(tester);

    final glass = tester.widget<AdaptiveGlassSurface>(_capsule());
    final rect = tester.getRect(_capsule());
    final height = rect.height;
    final expectedRadius = height / 2;
    // borderRadius 从 AdaptiveGlassSurface.borderRadius 取。
    final radius = glass.borderRadius.topLeft.x;
    expect(radius, moreOrLessEquals(expectedRadius, epsilon: 1));
    await _drain(tester);
  });
}
