import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/app/theme/hmusic_palette.dart';

// 开屏窗口底色（Android 的 LaunchTheme/NormalTheme）必须等于 App 自己的背景色：
// 差一档就会在 Flutter 画出首帧的那一瞬闪一下色阶，把品牌渐显的开场破了功。
// 系统默认给的是纯白/纯黑（Theme.Light / Theme.Black 的 colorBackground），
// 和 #F7F7F8 / #131315 都不一样，所以这两个值必须显式写死并跟着调色板走。
// 调色板改了而这两个 xml 没跟上，只有真机开 App 才看得见——这里机械守一层。
void main() {
  String launchColor(String path) {
    final String xml = File(path).readAsStringSync();
    final RegExpMatch? match = RegExp(
      r'<color name="hmusic_launch_background">(#[0-9A-Fa-f]{6})</color>',
    ).firstMatch(xml);
    expect(match, isNotNull, reason: '$path 里没有 hmusic_launch_background');
    return match!.group(1)!.toUpperCase();
  }

  String paletteHex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  test('Android 开屏底色与亮色调色板一致', () {
    expect(
      launchColor('android/app/src/main/res/values/colors.xml'),
      paletteHex(HMusicPalette.light.background.toARGB32()),
    );
  });

  test('Android 开屏底色与暗色调色板一致', () {
    expect(
      launchColor('android/app/src/main/res/values-night/colors.xml'),
      paletteHex(HMusicPalette.dark.background.toARGB32()),
    );
  });
}
