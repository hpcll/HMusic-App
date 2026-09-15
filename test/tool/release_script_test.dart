import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 0.1.3 的线上事故：发布脚本先删掉生成的 GeneratedPluginRegistrant.java，又用 --no-pub
// 构建，而这个文件只在 pub 步骤重新生成——正式包于是一个插件都没注册。FlutterEngine
// 缺注册表只打一行 warning 继续跑，构建全绿、包能装能开能连服务端，但点播报
// MissingPluginException、token 存不住、本地键值存储失效。发布脚本里的校验只在发版时
// 跑得到，这里再机械守一层：改坏这两条不变量，日常 flutter test 就红。
void main() {
  const List<String> scripts = <String>[
    'tool/build_release.sh',
    'tool/build_windows_release.ps1',
  ];

  // 只看真正会执行的行：两个脚本的注释里都写着「不能带 --no-pub」的来由，
  // 连注释一起 grep 会把解释自己判成违规。
  String commands(String path) => File(path)
      .readAsLinesSync()
      .where((String line) => !line.trimLeft().startsWith('#'))
      .join('\n');

  for (final String path in scripts) {
    test('$path 不跳过 pub：插件注册文件只在 pub 步骤生成', () {
      expect(commands(path), isNot(contains('--no-pub')));
    });

    test('$path 不删除 GeneratedPluginRegistrant', () {
      final RegExp deletion = RegExp(
        r'(rm\s+-f|Remove-Item).*GeneratedPluginRegistrant',
      );
      expect(deletion.hasMatch(commands(path)), isFalse);
    });

    // 校验值集中到 hmusic-<版本>-SHA256SUMS.txt 之后，谁再顺手写一个 <包>.sha256
    // 边车，Release 资产列表就又回到 14 条那种一团乱的样子。
    test('$path 只写汇总校验文件，不再生成 .sha256 边车', () {
      expect(commands(path), contains('SHA256SUMS.txt'));
      expect(commands(path), isNot(contains('.sha256')));
    });
  }

  // 工作流是按文件名 glob 收产物的（`if-no-files-found: error`），脚本改了产物名
  // 而 glob 没跟上，只有发版当天才会红。这里把两边的名字对起来机械守一层。
  test('发布工作流的资产 glob 与构建脚本的产物名一致', () {
    final String workflow = File(
      '.github/workflows/release-android.yml',
    ).readAsStringSync();
    final String macos = File('tool/build_release.sh').readAsStringSync();

    expect(macos, contains(r'hmusic-${VERSION}-macos-universal.dmg'));
    expect(workflow, contains('dist/*-macos-universal.dmg'));
    // 边车已经没有了，工作流里也不该再留 .sha256 的 glob。
    expect(workflow, isNot(contains('.sha256')));
    // 汇总文件由最后那个 checksums job 统一产出并追加到 Release。
    expect(workflow, contains('SHA256SUMS.txt'));
  });

  // 四个安卓包必须同号，否则装过分架构包的设备收到通用包会被安卓当降级拒装，只报一句
  // 「应用未安装」——网盘里放的正是不分架构的通用包。Flutter 的 --split-per-abi 默认会
  // 把分架构包的版本号改写成「芯片基数 * 1000 + 构建号」，靠 android/app/build.gradle.kts
  // 里的 versionCodeOverride 掰回来。这两处任一处被删掉，发版当天才会发现，这里先守一层。
  test('安卓四个包的 versionCode 统一：Gradle 掰回了 Flutter 的 ABI 改写', () {
    final String gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('ApkVariantOutput'));
    expect(gradle, contains('versionCodeOverride'));
    // 只碰 APK 产物：AAB 的输出不是 ApkVariantOutput，硬转会在 bundleRelease 崩。
    expect(gradle, contains('as?'));
  });

  test('发布脚本逐个校验安卓包版本号，并守住构建号下界', () {
    final String script = commands('tool/build_release.sh');

    expect(script, contains('apk_version_code.py'));
    expect(script, contains('MIN_ANDROID_VERSION_CODE'));
    expect(File('tool/apk_version_code.py').existsSync(), isTrue);
  });
}
