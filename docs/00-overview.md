# HMusic Desktop & Mobile — 客户端设计与实现文档

> 本目录是 HMusic 新客户端的**唯一事实源**。任何 AI 或开发者读完 `docs/` 即可动手写代码。
> 技术栈已定：**Tauri 2.x + 复用现有 web/ 前端**，目标 **桌面（macOS/Windows/Linux）+ 移动（iOS/Android）**。
>
> 维护约定：每完成一个里程碑，回来更新对应文档的「实现状态」；决策变更先改文档再改代码。

## 这个项目是什么

HMusic-Server（`/Users/pchu/AICODE/HMusic-Server`）是自建音乐后端——搜索/播放解析、
小爱音箱控制、榜单、统计、歌单，附一套**免构建的 Vue 3 SPA**（`web/` 目录）作为网页界面。

本项目 **HMusic-Desktop** 把那套网页前端用 **Tauri** 包成原生应用：
- **桌面**：一套代码出 macOS `.dmg` / Windows `.msi` / Linux `.AppImage`，包体 3–10MB
- **移动**：Tauri 2.x 支持 iOS / Android，同一套 `web/` 代码
- **视觉**：与网页端 **1:1 一致**（同一份设计 token，见 `03-design-system.md`）

它取代已弃坑的第三方 xiaomusic，是 HMusic 生态的官方客户端。

## 为什么是 Tauri（而非 Electron / Flutter）

| | Tauri 2.x ✅ | Electron | Flutter |
|---|---|---|---|
| 复用现有 web/ 代码 | ✅ 直接用 | ✅ 直接用 | ❌ Dart 重写 |
| 包体积 | 3–10MB | 80–150MB | 15–40MB |
| 桌面 | ✅ | ✅ | ✅ |
| 移动 iOS/Android | ✅ (2.x) | ❌ | ✅ |
| webview | 系统自带 | 内置 Chromium | 自绘引擎 |

核心理由：**网页端已是免构建纯静态 SPA，Tauri 几乎零改造就能复用，还独占「小体积 + 全平台（含移动）」。**

## 文档索引

| 文档 | 内容 | 读者 |
|---|---|---|
| `00-overview.md` | 本文件：项目定位、技术选型、里程碑 | 所有人先读 |
| `01-architecture.md` | 目录结构、Tauri 配置、web 复用策略、构建打包 | 搭骨架的人 |
| `02-server-api.md` | 后端 API 全量契约（端点/入参/出参/错误码） | 写数据层的人 |
| `03-design-system.md` | 设计 token、组件规格、动效清单（1:1 复刻依据） | 写 UI 的人 |
| `04-screens.md` | 逐屏 UI 结构 + 交互 + 调用的 API | 写页面的人 |
| `05-interactions-animations.md` | 交互模式与动画规范（含桌面/移动差异、原生增强） | 写交互的人 |
| `06-platform-native.md` | 各平台原生能力（托盘/全局快捷键/媒体键/深链/通知） | 做原生集成的人 |
| `07-roadmap.md` | 里程碑拆解与验收清单 | 排期与验收 |
| `08-audio-plugin.md` | 移动音频插件完整规格（命令/事件/中断矩阵/两端实现/验收） | 写移动本机播放的人 |

## 里程碑速览（详见 `07-roadmap.md`）

- **M0 骨架**：Tauri 项目跑起来，webview 加载现有 web/，能连本地 Server 登录
- **M1 核心闭环**：登录→搜索→播放→队列 全通，本机播放引擎在 Tauri webview 里工作
- **M2 全页对齐**：歌单/榜单/统计/设置 7 页全部复刻，视觉 1:1
- **M3 原生增强**：系统托盘、全局媒体键、迷你播放器窗口、开机自启
- **M4 移动端**：iOS/Android 含**本机播放**（硬性需求：自研原生音频插件，锁屏/后台出声）
- **M5 打包分发**：三桌面平台 + 双移动平台出安装包，签名与自动更新

## 实现状态

- [x] 需求确认（技术栈 Tauri、桌面+移动全覆盖）
- [x] 文档撰写（本轮 8 份文档）
- [ ] M0 骨架
