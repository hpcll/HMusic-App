# HMusic App - 客户端总览

> 本目录是客户端设计与实现的事实源。技术栈已在 2026-07-11 定案为 **Flutter 原生 UI**，
> 不再使用 Tauri 或复用 WebView 页面。

## 1. 产品边界

HMusic-Server 提供鉴权、搜索、解析、持久化队列/播放态、服务端下载、播放控制、歌单、榜单、
统计、小米设备和音频代理。
HMusic App 是 NAS/家庭服务器个人音乐库的跨平台客户端，负责服务端连接、队列/歌单等界面，
以及手机/电脑自身出声时的原生播放器；它不是公共在线音乐平台。

目标平台：

- P0-P3：Android、iOS 优先，同时保持 macOS/Windows/Linux 可编译。
- P4：补齐桌面托盘、媒体键、窗口状态和安装包体验。
- P5：五平台发布、签名和升级。

Web 页面继续由 HMusic-Server 独立维护；Flutter 客户端以其产品行为和视觉结果为参考，
但不复制 JavaScript/CSS，也不嵌套 WebView。

视觉架构采用“内容品牌层 + 平台 chrome 层”：Flutter 内容区保留 HMusic 的暖纸、墨色、衬线
和克制青绿；iOS 27 的底栏、mini player 与控制面板由 Swift/SwiftUI 使用系统液态玻璃
能力实现；Android 由 Flutter 提供同构玻璃材质，并按设备性能与无障碍设置降级。

## 2. 为什么改为 Flutter

| 约束 | Flutter 结论 |
|---|---|
| iOS/Android 锁屏、后台连续播放 | `audio_service` + `just_audio` 有成熟的后台任务与媒体会话模型 |
| 统一五平台 UI | 单 Dart 代码库，避免 WebView 内核差异 |
| 移动端固定应用骨架 | `Scaffold` + `bottomNavigationBar` 天然满足上一轮真机验证结论 |
| 沉浸歌词、逐帧染色 | Flutter ticker/shader 可直接控制，不依赖 CSS/WebView 调度 |
| iOS 27 系统液态玻璃 | Swift/SwiftUI 薄原生外壳，Flutter 继续持有业务状态和页面内容 |
| 代价 | 不能复用 Web 代码；必须建立清晰的 API 模型与视觉对照验收 |

## 3. 核心状态所有权

| 状态 | 事实源 |
|---|---|
| 登录、队列、播放模式、当前曲目、目标设备 | HMusic-Server |
| 本机播放实时位置、缓冲、音频焦点、中断 | Flutter `AudioHandler` / `just_audio` |
| 页面路由、筛选、弹层、临时输入 | Flutter UI |
| server base | 本地配置，前后台音频进程共享 |

本机播放每 3 秒调用 `/playback/local-report` 回写；播放结束以 `ended:true` 让服务端推进队列，
再消费返回的新 `streamUrl`。客户端不能在本地另造一套权威队列。

## 4. 文档索引

| 文档 | 内容 |
|---|---|
| `01-architecture.md` | Flutter 工程结构、数据流、网络和状态边界 |
| `02-server-api.md` | API 契约、接入规则和已知缺口 |
| `03-design-system.md` | 内容品牌、组件、响应式与平台玻璃材质规则 |
| `04-screens.md` | 逐屏结构、交互与 API |
| `05-interactions-animations.md` | 动效、手势、快捷键 |
| `06-platform-native.md` | Flutter + Swift 平台壳、iOS/Android/桌面能力 |
| `07-roadmap.md` | P0-P5 验收路线 |
| `08-audio-plugin.md` | Flutter 后台音频实现规格 |
| `09-p0-audit.md` | 本轮 Server/App 审计和开工门禁 |
| `10-engineering-standards.md` | MVVM、文件拆分、复用、依赖准入与 Code Review 门禁 |
| `11-release-compliance.md` | App Store/Google Play、隐私、内容权利、审核环境与签名 |
| `12-server-compatibility.md` | 当前 Server 契约缺口、兼容调用、重试和降级规则 |
| `decisions/ADR-0002-app-store-positioning.md` | NAS/家庭服务器个人音乐库产品定位与商店文案 |
| `decisions/ADR-0003-store-edition-demo-server-https.md` | 商店首发功能边界、Demo Server、公网 HTTPS/LAN HTTP 策略 |

## 5. 实现状态

- [x] 移动端 Web 交互真机验证并回写视觉规格
- [x] 技术栈由 Tauri 改为全 Flutter
- [x] P0 Server/App 静态审计与文档统一
- [ ] 关闭 P0 服务端阻塞项
- [ ] 生成 Flutter 工程并打通连接、鉴权、搜索、播放纵切
