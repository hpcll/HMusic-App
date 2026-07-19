import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/hmusic_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 移动端把焦点高亮锁死为触摸模式：实体键（音量/返回）会把高亮切到键盘模式，
  // 既让 InkWell 平白冒出焦点框，还会在路由退场瞬间触发 framework 已知断言
  //（_HighlightModeManager 通知已 deactivate 的 InkWell 查 MediaQuery）。
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
  }
  runApp(const ProviderScope(child: HMusicApp()));
}
