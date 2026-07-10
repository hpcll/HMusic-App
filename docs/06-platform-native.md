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

## M4 移动（本机播放 = 硬性需求）

> **决策（2026-07-10 用户拍板）**：移动端必须支持本机播放——手机自己出声，且锁屏/后台继续播。
> webview 的 `<audio>` 进后台即被系统挂起，此路不通——移动本机播放**必须走原生音频层**。
> 「遥控器模式」只允许作为开发过程中的临时过渡，**不是交付形态**。

### 架构：可替换音频后端（配合 01 章决策 E）

main.js 本机播放引擎抽出「音频后端」接口，两个实现：

| 后端 | 平台 | 实现 |
|---|---|---|
| HTMLAudioBackend | 浏览器 / 桌面 Tauri | 现有 `<audio>` 逻辑原样（含 prime 手势解锁） |
| NativeAudioBackend | iOS / Android | 自研 Tauri 移动插件（下述） |

引擎其余编排（跟随 playback.state 换源、3s local-report 回写、ended 推进队列、seek/播放暂停/音量）
**一行不改**——换的只是执行者。服务端也零改动：原生播放器直接流式拉同一个 streamUrl（音频代理地址）。

### tauri-plugin-hmusic-audio（自研移动插件，M4 主工程量）

**完整规格见 `08-audio-plugin.md`**（命令/事件/错误码/中断矩阵/两端实现要点/验收矩阵），
此处只留形态结论：

- 插件是「迷你客户端」：持有 serverBase+token。**后台 webview JS 会被系统挂起**，
  锁屏控制、播完推进队列等原生自主动作由插件**直连服务端**完成，再广播 `audio:state`
  给（可能活着的）JS 对齐——这消灭了双重推进与前后台状态打架两类必然 bug。
- 锁屏/耳机控制不走 `media:*` 事件回 JS（JS 可能睡着）；`media:*` 仅桌面媒体键使用。

### 其余移动事项

| 能力 | iOS | Android |
|---|---|---|
| 锁屏/控制中心 | 插件内 MPNowPlayingInfoCenter | 插件内 MediaSession 通知 |
| 深链 | `hmusic://` scheme 预留 | 同左 |
| 手势层 | docs/05 §3（封面滑切歌、列表左滑、下拉刷新） | 同左 |

## 安全

- token 仍存 localStorage（webview 沙箱内，风险面等同浏览器）。
- 服务器地址允许 http（家庭局域网现实），但 UI 提示公网部署请上 https。
- CSP 置 null 的补偿：不加载任何远程 JS，全部代码本地打包；webview 禁用 devtools（release 构建默认）。

## 实现状态
- [ ] M0 项
- [ ] 托盘 / 媒体键 / 通知 / 自启
- [ ] 音频后端抽象（决策 E）合入 HMusic-Server
- [ ] tauri-plugin-hmusic-audio（iOS / Android）
