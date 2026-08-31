import 'package:flutter_riverpod/flutter_riverpod.dart';

// 开屏动画的一次性闸门。
//
// 开场（字标在正中淡入 → 推到位 → 下方内容显形）只属于**冷启动那一程**。
// 热启动（进程还活着、从后台切回来）根本不会重建连接页，本来就不会重放；真正
// 需要挡的是同一进程里再次落到连接页的路径——退出登录、更换服务器、换服务器
// 失败后返回。用户点一下按钮不该再看一遍两秒的开场。
//
// 放在 Provider 里而不是全局静态变量：每个 ProviderScope 一份，测试之间天然
// 隔离（静态变量会让第一个测试消费掉闸门，后面全部看到"已放过"）。
final Provider<AppOpening> appOpeningProvider = Provider<AppOpening>(
  (ref) => AppOpening(),
);

class AppOpening {
  bool _played = false;

  // 领取开场资格：整个进程只有第一个调用者拿到 true。
  bool claim() {
    if (_played) return false;
    _played = true;
    return true;
  }
}
