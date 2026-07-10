# 06 · 平台原生能力

> 读者：做原生集成的人（Rust 侧 + native/ 桥接层）。按里程碑排列，每项给「用什么实现 + 桥接方式」。

## 桥接总原则

webview ↔ Rust 只走两条路：
1. `invoke("cmd", args)` —— 前端主动调 Rust（如读写窗口状态）。
2. `emit/listen` 事件 —— Rust 推给前端（如媒体键按下 → `media:next`）。

全部封装在 `src/native/tauri-bridge.js`，浏览器环境（无 `window.__TAURI__`）全 no-op，
保证同一份代码网页端照跑。

## M0/M1（跟骨架一起）

| 能力 | 实现 |
|---|---|
| 外链系统浏览器打开 | `shell:allow-open`；拦截 `<a target=_blank>`/`window.open` |
| 窗口状态记忆 | tauri-plugin-window-state |
| macOS 标题栏 Overlay | tauri.conf `titleBarStyle:"Overlay"` + 侧栏顶部留红绿灯区（native 注入 CSS 补丁） |
| 深浅色跟随系统 | 免费——webview 的 `prefers-color-scheme` 原生生效，CSS 已双套 token |

## M3 桌面增强

### 系统托盘（tray + menu 权限）
- 图标：墨色单色 template image（macOS 自动适配深浅菜单栏）。
- 菜单：`正在播放·<题>`（disabled 行）/ 播放暂停 / 上一曲 / 下一曲 / 显示主窗口 / 退出。
- 状态同步：前端每次 refreshPlayback 后 `invoke("tray_update", {title, state})` 更新菜单文案。
- 关窗隐藏到托盘（`onCloseRequested` preventDefault + hide），托盘/Dock 点击恢复。

### 全局媒体键 + 系统「正在播放」
- crate：`souvlaki`（跨平台 MPRemoteCommandCenter / SMTC / MPRIS 封装）。
- Rust 收到 play/pause/next/prev → `emit("media:<action>")` → boot.js listen → 调 `/playback/*`。
- 前端每次曲目变化 `invoke("now_playing", {title, artist, coverUrl, durationMs, positionMs, playing})`
  → Rust 喂给系统面板（macOS 控制中心 / Windows 媒体浮层 / Linux MPRIS）。

### 通知（notification 权限）
- 切歌时系统通知（题 + 歌手 + 封面），仅窗口隐藏时发，设置里可关。

### 开机自启
- tauri-plugin-autostart，设置页加开关（存 localStorage，boot 时 invoke 同步）。

## M4 移动

| 能力 | iOS | Android |
|---|---|---|
| 后台播放 | AVAudioSession category=playback（Xcode 工程 capability + 原生侧激活） | 前台服务 + 常驻通知 |
| 锁屏/控制中心 | MPNowPlayingInfoCenter + RemoteCommand | MediaSession + MediaStyle 通知 |
| 深链 | `hmusic://` scheme（后续分享/唤起用，预留） | 同左 |

> 移动端本机播放的 `<audio>` 在 webview 后台会被系统暂停——**后台播放必须走原生音频层或
> 保活 webview**，这是 M4 的核心技术攻关点，动手前先做 spike 验证（1-2 天盒内试验）。
> 备选方案：移动端主打「遥控器模式」（控制音箱/桌面端），本机播放仅前台可用——零攻关成本，
> 家庭场景够用。**spike 失败即回退此方案。**

## 安全

- token 仍存 localStorage（webview 沙箱内，风险面等同浏览器）。
- 服务器地址允许 http（家庭局域网现实），但 UI 提示公网部署请上 https。
- CSP 置 null 的补偿：不加载任何远程 JS，全部代码本地打包；webview 禁用 devtools（release 构建默认）。

## 实现状态
- [ ] M0 项
- [ ] 托盘 / 媒体键 / 通知 / 自启
- [ ] 移动后台播放 spike
