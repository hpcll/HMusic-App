import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/shared/layout/shell_metrics.dart';

// 用户反馈：安卓上底部 dock 栏和手势条重叠。根因是底距对两个平台用了同一个
// 「安全区 − 10」：iOS 的 34pt 里 home indicator 只占底部约 13pt，减 10 仍有
// 呼吸；安卓手势条的安全区（这台机器 16dp）几乎就等于那颗胶囊自身，减完直接
// 压在上面。这里按「胶囊底缘必须落在安全区之外」机械守住。
void main() {
  test('安卓：chrome 底距让开整条安全区，手势条与三键导航都不压', () {
    // 手势条（真机 16dp）：让开 16 再留呼吸。
    expect(
      chromeBottomOffset(16, platform: TargetPlatform.android),
      greaterThan(16),
    );
    // 三键导航（48dp 实体栏）：同理不能减。
    expect(
      chromeBottomOffset(48, platform: TargetPlatform.android),
      greaterThan(48),
    );
    // 无安全区（模拟器/平板）：仍留一点余量，不贴死屏幕底边。
    expect(
      chromeBottomOffset(0, platform: TargetPlatform.android),
      greaterThan(0),
    );
  });

  test('iOS：保持与原生玻璃壳 GlassShellMetrics.bottomOffset 同式', () {
    expect(chromeBottomOffset(34, platform: TargetPlatform.iOS), 24);
    expect(chromeBottomOffset(0, platform: TargetPlatform.iOS), 10);
  });
}
