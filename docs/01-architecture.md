# 01 · 架构与工程结构

> 读者：搭项目骨架的人。读完本文即可初始化仓库、配置 Tauri、跑起第一个窗口。

## 1. 核心架构决策

### 决策 A：前端代码「引用」而非「拷贝」HMusic-Server 的 web/

`HMusic-Server/web/` 是**免构建**纯静态 SPA（Vue 3 ESM 浏览器版 + `h()` 渲染函数 +
importmap，无任何打包步骤）。客户端**不复制**这份代码，而是构建时同步：

```
HMusic-Desktop/
├── src/                    # 前端（从 HMusic-Server/web 同步 + 客户端增量）
│   ├── (同步) index.html / main.js / api.js / icons.js / styles.css
│   ├── (同步) views/ components/ vendor/ assets/
│   └── native/             # 客户端专属增量（见 §4，不回流到 Server）
├── src-tauri/              # Rust 壳
│   ├── tauri.conf.json
│   ├── Cargo.toml
│   ├── capabilities/       # Tauri 2.x 权限声明
│   ├── icons/
│   └── src/main.rs + lib.rs
├── scripts/
│   └── sync-web.sh         # 从 ../HMusic-Server/web 同步前端（rsync，排除 native/）
└── docs/                   # 本文档
```

**同步规则**（`scripts/sync-web.sh`）：
- `rsync -a --delete ../HMusic-Server/web/ src/ --exclude 'native/'`
- 同步后打补丁：在 `index.html` 注入 `<script type="module" src="/native/boot.js"></script>`（幂等，见 §4）
- 网页端永远是 UI 的事实源；客户端专属逻辑只放 `src/native/`，绝不改同步来的文件
  （避免双向漂移——需要改 UI 就去 HMusic-Server 改，再同步过来）

### 决策 B：API 基址改为「可配置」（唯一必须动的前端差异）

网页端 `api.js` 用相对路径 `fetch("/api/v1" + path)`——因为页面本身由 Server 伺服。
客户端里页面来自本地 `tauri://` 协议，**必须显式指定服务器地址**。

改造方式（在 HMusic-Server 的 web/api.js 里做，网页端行为不变）：

```js
// api.js 顶部新增（对网页端零影响：BASE 为空串时保持原相对路径行为）
const BASE_KEY = "hmusic.serverBase";
export function getServerBase() { return localStorage.getItem(BASE_KEY) || ""; }
export function setServerBase(url) {
  if (url) localStorage.setItem(BASE_KEY, url.replace(/\/+$/, ""));
  else localStorage.removeItem(BASE_KEY);
}
// fetch 调用处：fetch(`${getServerBase()}/api/v1${path}`, ...)
```

配套两处同样加 BASE 前缀：
1. `main.js` 的 `toSameOriginUrl()` —— 本机播放的 streamUrl 处理。客户端里不能再转
   相对路径，要转成 `getServerBase() + pathname + search`（webview 的 origin 是 tauri://，
   相对路径拉不到流）。判断：`getServerBase()` 非空走新逻辑，否则保持原逻辑。
2. 登录页 `login.js` —— 首屏若 `getServerBase()` 为空且非浏览器环境（`window.__TAURI__` 存在），
   先渲染「连接服务器」表单（输入 `http://IP:8090`，请求 `/api/v1/auth/status` 探活成功才进登录）。

### 决策 C：CORS 已就绪，无需服务端改动

`HMusic-Server/src/app.ts` 已配置 `cors { origin: true }`，`tauri://localhost` /
`http://tauri.localhost` 的跨域请求直接放行。**服务端零改动。**

### 决策 D：本机播放引擎直接复用（桌面）

`main.js` 的全局 `<audio>` 引擎（手势解锁 primeLocalAudio、3s 进度回写 local-report、
ended 推进队列）在 Tauri webview（macOS WKWebView / Windows WebView2）里原样工作。
唯一注意点：桌面 webview 的自动播放策略比浏览器宽松（Tauri 可配
`macOSPrivateApi`/webview 参数放开 autoplay），但**保留手势解锁逻辑不删**——移动端 webview 仍需要它。

### 决策 E：本机播放引擎抽「音频后端」接口（移动本机播放的地基）

**移动端本机播放是硬性需求**（手机自己出声 + 锁屏/后台继续播，2026-07-10 用户拍板），
而 webview `<audio>` 进后台即被系统挂起——移动端必须换**原生播放器**出声。

改造方式（在 HMusic-Server/web/main.js 做，网页端零行为变化）：

```js
// 把对 <audio> 的直接操作收拢成后端对象（接口）：
audioBackend = {
  load(url, meta, positionMs, autoplay), play(), pause(), stop(),
  seek(ms), setVolume(0..1), positionMs(), durationMs(),
  prime(),                     // 手势解锁；原生后端为 no-op
  onEnded(cb), onError(cb),
}
// 默认实现 = 现有 HTMLAudio 逻辑；另导出 setAudioBackend(backend) 钩子。
```

- 移动端 `native/boot.js` 检测 iOS/Android → `setAudioBackend(NativeAudioBackend)`
  （桥到自研 `tauri-plugin-hmusic-audio`，见 docs/06 M4）。
- `syncLocalAudio` / `startLocalReporting` / ended→local-report 等**编排逻辑一行不动**，只换执行者。
- 服务端零改动：原生播放器流式拉同一个 streamUrl（音频代理地址）。

## 2. Tauri 配置要点（src-tauri/tauri.conf.json）

```jsonc
{
  "productName": "HMusic",
  "identifier": "com.hmusic.desktop",
  "build": {
    "frontendDist": "../src",     // 免构建：直接指静态目录，无 devServer/打包命令
    "beforeBuildCommand": "bash scripts/sync-web.sh"
  },
  "app": {
    "windows": [{
      "title": "HMusic",
      "width": 1200, "height": 800,
      "minWidth": 900, "minHeight": 640,
      "titleBarStyle": "Overlay",   // macOS 沉浸标题栏（见 06 章）
      "hiddenTitle": true
    }],
    "security": { "csp": null }     // 允许连任意用户填的服务器地址与封面 CDN
  }
}
```

- **frontendDist 直指 src/**：网页端本来就免构建，Tauri 不需要 npm build。
- **CSP 置 null**：曲库封面来自 QQ/网易/Apple 多家 CDN，服务器地址用户自填，白名单不现实。
  风险可控（UI 代码全部本地，无远程代码执行面）。
- 移动端（M4）：`tauri android init` / `tauri ios init` 生成工程，同一 frontendDist。

## 3. 权限（src-tauri/capabilities/default.json）

Tauri 2.x 按能力声明。本项目初期只需要：

| 能力 | 用途 | 里程碑 |
|---|---|---|
| `core:default` | 窗口基本操作 | M0 |
| `shell:allow-open` | 外链用系统浏览器打开 | M0 |
| `tray` + `menu` | 系统托盘 | M3 |
| `global-shortcut` | 全局媒体键 | M3 |
| `notification` | 切歌通知 | M3 |
| `autostart`（插件） | 开机自启 | M3 |

网络请求走 webview 内 `fetch`（不经 Tauri http 插件），无需 http 权限。

## 4. src/native/ —— 客户端专属层

同步脚本不会碰这个目录。内容：

```
src/native/
├── boot.js        # 唯一入口：检测 window.__TAURI__，注册桌面增强（媒体键桥、托盘状态推送）
├── server-setup.js# 「连接服务器」首屏组件（决策 B）
└── tauri-bridge.js# 封装 invoke/event，浏览器环境全部 no-op
```

**关键原则：native 层全部「渐进增强」**——同一份代码在纯浏览器里打开也能跑
（`__TAURI__` 不存在时 native 功能静默失活）。这保证网页端与客户端永远同一套 UI 代码。

## 5. 构建与分发

| 目标 | 命令 | 产物 |
|---|---|---|
| 开发 | `cargo tauri dev` | 本地窗口（热改 src/ 刷新即生效，免构建红利） |
| macOS | `cargo tauri build` | `.app` / `.dmg`（aarch64 + x86_64 用 `--target universal-apple-darwin`） |
| Windows | `cargo tauri build`（Win 机或 CI） | `.msi` / `.exe`(NSIS) |
| Linux | 同上 | `.AppImage` / `.deb` |
| Android | `cargo tauri android build` | `.apk` / `.aab` |
| iOS | `cargo tauri ios build` | `.ipa`（需开发者证书） |

CI 建议：GitHub Actions 的 `tauri-apps/tauri-action`，tag 触发三平台矩阵构建。
自动更新（M5）：`tauri-plugin-updater` + GitHub Releases 作为更新源。

## 6. 与 HMusic-Server 仓库的关系

- 本仓库独立 git（将来可独立开源），文档随代码走。
- `sync-web.sh` 假设两仓库同级目录（`../HMusic-Server`）；CI 里用 submodule 或 checkout 两仓库。
- **UI 改动流向**：永远 HMusic-Server/web → 同步 → 本仓库。本仓库只改 native/ 与 Rust 壳。

## 实现状态

- [ ] 仓库初始化 + sync-web.sh
- [ ] tauri.conf.json 按本文配置
- [ ] api.js 的 serverBase 改造（在 HMusic-Server 侧做）
- [ ] native/boot.js 骨架
