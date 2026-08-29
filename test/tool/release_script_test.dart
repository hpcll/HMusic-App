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
  }
}
