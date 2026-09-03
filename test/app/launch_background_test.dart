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

  // Android 12+ 起系统自己画开屏，默认在正中放启动器图标，一直挂到 Flutter 首帧。
  // 留着它，用户「一打开就看到一个 icon 在中间」，连接页那段「字标从正中慢慢淡入」
  // 就永远没机会发生（真机反馈原话：不是慢慢显示，是打开他就显示了，然后突然滑到
  // 最后的位置）。图标位换成全透明后开屏只剩底色。
  //
  // 亮暗两份都要有：资源匹配里 night 限定符的优先级高于版本号，只写 values-v31
  // 的话，暗色下会挑中 values-night/styles.xml，这几个属性整套丢失。
  group('Android 12+ 系统开屏不放居中图标', () {
    for (final String path in const <String>[
      'android/app/src/main/res/values-v31/styles.xml',
      'android/app/src/main/res/values-night-v31/styles.xml',
    ]) {
      test(path, () {
        final String xml = File(path).readAsStringSync();
        expect(
          xml,
          contains(
            '<item name="android:windowSplashScreenAnimatedIcon">'
            '@drawable/splash_no_icon</item>',
          ),
        );
        // 系统只在 windowBackground 是单一颜色时才拿它当开屏底色；我们的
        // launch_background 是 layer-list，所以这一项必须显式写。
        expect(
          xml,
          contains(
            '<item name="android:windowSplashScreenBackground">'
            '@color/hmusic_launch_background</item>',
          ),
        );
      });
    }
  });

  test('系统开屏图标位那张图是全透明的', () {
    final String xml = File(
      'android/app/src/main/res/drawable/splash_no_icon.xml',
    ).readAsStringSync();
    expect(xml, contains('@android:color/transparent'));
  });
}
