import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/platform_shell/widgets/adaptive_glass_surface.dart';

// 底缘渐隐（bottomFade，顶栏用）：玻璃档 tint 换成「上 80% 全浓度、底部
// 渐隐到全透明」的渐变，不画亮度台阶；off 档（高对比）忽略渐隐保持实底，
// 分隔交还调用方的 hairline。
void main() {
  Future<void> pumpSurface(WidgetTester tester, GlassQuality quality) {
    return tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: AdaptiveGlassSurface(
            quality: quality,
            bottomFade: true,
            borderRadius: BorderRadius.zero,
            border: const Border(),
            shadow: false,
            padding: EdgeInsets.zero,
            child: const SizedBox(width: 120, height: 80),
          ),
        ),
      ),
    );
  }

  BoxDecoration surfaceDecoration(WidgetTester tester) {
    // 首个 DecoratedBox 是玻璃底面（第二个是悬浮卡的顶缘高光层）。
    final box = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(AdaptiveGlassSurface),
            matching: find.byType(DecoratedBox),
          ),
        )
        .first;
    return box.decoration as BoxDecoration;
  }

  testWidgets('玻璃档：tint 为底缘渐隐渐变，末色全透明', (tester) async {
    await pumpSurface(tester, GlassQuality.medium);

    final decoration = surfaceDecoration(tester);
    expect(decoration.color, isNull);
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors.last.a, 0);
    expect(gradient.colors.first.a, greaterThan(0));
  });

  testWidgets('off 档：忽略渐隐，保持不透明实底', (tester) async {
    await pumpSurface(tester, GlassQuality.off);

    final decoration = surfaceDecoration(tester);
    expect(decoration.gradient, isNull);
    expect(decoration.color, isNotNull);
    expect(decoration.color!.a, 1);
  });
}
