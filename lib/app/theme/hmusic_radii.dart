// 圆角 token：整体从 web 的 10/7 提升一档（14/10），风格向悬浮胶囊 chrome
// 的圆润语言靠拢（Apple Music 参照）；胶囊类（按钮/搜索框/dock/mini）直接用
// StadiumBorder/半高圆角，不走这里。改动时同步 docs/03 §1。
abstract final class HMusicRadii {
  // 卡片、弹窗、菜单卡（web --radius:10 → 柔化 14）。
  static const double card = 14;

  // 行内小件：曲目行、toast、列表项 hover 面（web --radius-sm:7 → 柔化 10）。
  static const double small = 10;

  // 输入框：灰底无描边的柔和大圆角（对齐系统级登录表单的软胶囊观感）。
  static const double input = 14;
}
