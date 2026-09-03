import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/hmusic_app.dart';
import 'shared/widgets/brand_mark.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android) {
    // 显式声明 edge-to-edge。targetSdk 35+ 在 Android 15+ 上本就被系统强制画到
    // 导航条后面，但引擎的键盘动画同步（ImeSyncDeferringInsetsCallback）只认
    // 窗口上的 LAYOUT_HIDE_NAVIGATION 标志：没有它，动画每帧上报的 IME inset
    // 都被减掉一个导航条高度，动画结束再换成完整值——内容跟着键盘上来时
    // 差 16dp，停稳后自己再跳一下。声明之后动画帧与最终帧口径一致；旧系统
    // 也因此与 Android 15+ 同一套布局（各页已按 MediaQuery.padding 让位）。
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  // 移动端把焦点高亮锁死为触摸模式：实体键（音量/返回）会把高亮切到键盘模式，
  // 既让 InkWell 平白冒出焦点框，还会在路由退场瞬间触发 framework 已知断言
  //（_HighlightModeManager 通知已 deactivate 的 InkWell 查 MediaQuery）。
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
  }
  // 品牌字标是开场第 1 幕唯一的主体：首帧之前先把它解码好，否则淡入的是个空盒子，
  // 图片就绪时"啪"地满不透明出现（见 BrandWordmark.warmUp）。代价是开屏窗口多停
  // 几十毫秒——底色与 App 一致，看不出交接。
  await BrandWordmark.warmUp();
  runApp(const ProviderScope(child: HMusicApp()));
}
