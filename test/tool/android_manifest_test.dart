import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Impeller 关闭这件事在开发机上看不出来（花屏只在部分 Adreno 驱动上复现），
// 一行 meta-data 被顺手删掉也不会让任何测试变红、任何构建失败——只有用户会
// 看到整屏花一下。所以在这里机械守住：删这行必须是明确决定，且要顺手更新
// AndroidManifest 里的说明和 TopEdgeScrim 的回退链注释。
void main() {
  test('AndroidManifest 保持关闭 Impeller：绕开 Adreno 驱动整屏花屏', () {
    final String manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final RegExp flag = RegExp(
      r'android:name="io\.flutter\.embedding\.android\.EnableImpeller"\s*'
      r'android:value="false"',
    );
    expect(flag.hasMatch(manifest), isTrue);
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
