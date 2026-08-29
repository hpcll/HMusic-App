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
}
