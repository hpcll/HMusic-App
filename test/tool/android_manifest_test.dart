import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Impeller 开关这件事在开发机上看不出来（花屏只在部分 Adreno 驱动上复现），
// meta-data 一行被顺手改掉也不会让任何测试变红、任何构建失败——只有用户会
// 看到整屏花一下。所以在这里机械守住：改这个开关必须是明确决定，且要顺手更新
// AndroidManifest 里的说明和 TopEdgeScrim 的回退链注释。
// 2026-09-04：小米（Mali）spike 已过（零花屏 + 滚动帧 p95=2.38ms，见 docs/06），
// Impeller 保持开启；**iQOO（Adreno）复测通过前，构建不进 release**。
void main() {
  test('AndroidManifest 保持开启 Impeller：小米 spike 已过，iQOO 复测前不发版', () {
    final String manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final RegExp flag = RegExp(
      r'android:name="io\.flutter\.embedding\.android\.EnableImpeller"\s*'
      r'android:value="false"',
    );
    expect(flag.hasMatch(manifest), isFalse);
  });

  // 同类：main.dart 显式声明 SystemUiMode.edgeToEdge。Android 15+ 本就强制
  // edge-to-edge，删掉这行画面一个像素都不变，但引擎的键盘动画同步只认窗口上的
  // LAYOUT_HIDE_NAVIGATION 标志——没有它，键盘动画每帧上报的 inset 少一个导航条
  // 高度、停稳再补跳（真机日志：动画末帧与终值差 60 物理像素）。用例测不出，守源码。
  test('main.dart 显式声明 edge-to-edge：键盘动画帧与终值口径一致', () {
    final String main = File('lib/main.dart').readAsStringSync();
    expect(
      main,
      contains('SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)'),
    );
  });
}
