// native/boot.js —— 客户端专属增强的唯一入口。
// sync-web.sh 会把本文件的 <script> 注入 index.html。
// 铁律：浏览器环境（无 window.__TAURI__）下全部静默失活，保证同一份 UI 代码网页端照跑。

import { isTauri } from "/native/tauri-bridge.js";

if (isTauri()) {
  // 桌面/移动原生增强按里程碑逐步接入（见 docs/05、06）：
  //   - 键盘快捷键（Space 播放暂停 / ⌘F 搜索 / ⌘1..7 切页 / ←→ seek / ↑↓ 音量）
  //   - 媒体键桥（listen media:play|pause|next|previous → 调 /playback/*）
  //   - 托盘状态推送（refreshPlayback 后 invoke tray_update / now_playing）
  //   - 移动手势层（封面滑动切歌 / 列表左滑 / 下拉刷新）
  // 目前占位：仅标记环境，供 UI 层按需读取。
  document.documentElement.dataset.hmusicShell = "tauri";
  console.info("[hmusic] native shell active");
}
