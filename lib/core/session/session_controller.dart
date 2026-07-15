import 'package:flutter/foundation.dart';

// 跨页面、跨生命周期的会话失效单飞。任意 401 触发一次「停本机音频 + 回登录」，
// 登录或重连成功后 markValid 复位，使下一次失效能再次通知。
// 同时充当 go_router 的 refreshListenable：notifyListeners 驱动 redirect 重算。
class SessionController extends ChangeNotifier {
  bool _invalid = false;

  bool get isInvalid => _invalid;

  // 登录 / setup / 连接成功后调用，复位强制登出标志。
  void markValid() {
    if (!_invalid) return;
    _invalid = false;
    notifyListeners();
  }

  // 401 时 ApiClient 调用；重复 401 只通知一次，避免多请求重复弹窗/导航。
  void invalidate() {
    if (_invalid) return;
    _invalid = true;
    notifyListeners();
  }
}
