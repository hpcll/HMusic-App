# HMusic App - 客户端总览

> 本目录是客户端设计与实现的事实源。技术栈已在 2026-07-11 定案为 **Flutter 原生 UI**，
> 不再使用 Tauri 或复用 WebView 页面。
>
> **当前状态（2026-09-17）**：已发布至 **v0.1.9**（`0.1.9+4009`），P0/P1/P2 验收条目全绿。
> 正在收口 P3 移动质量、P5 分发合规、P7 直连模式真机实测。逐项事实与门禁见
> [`09-p0-audit.md`](09-p0-audit.md)，阶段清单见 [`07-roadmap.md`](07-roadmap.md)。

## 1. 产品边界

HMusic-Server 提供鉴权、搜索、解析、持久化队列/播放态、服务端下载、播放控制、歌单、榜单、
统计、小米设备和音频代理。
HMusic App 是 NAS/家庭服务器个人音乐库的跨平台客户端，负责服务端连接、队列/歌单等界面，
以及手机/电脑自身出声时的原生播放器；它不是公共在线音乐平台。

**三种运行模式**：Server/直连于 v0.1.8 提供；纯播放器为 2026-09-18 工作树新增，尚未发布。
连接页与设置页均可选择：

| 模式 | 依赖 | 事实源 |
|---|---|---|
| **Server 模式** | 自建 HMusic-Server | Server 持有登录、队列、播放态和目标设备 |
| **直连模式** | 无需 Server，App 内直连小米音乐上游 | 本地仓库持有队列与播放态；小米凭据进安全存储 |
| **纯播放器** | 无需 Server 或小米登录，导入本机 LX 音源 | 复用直连本地数据，固定本机播放，不读取小米凭据 |

三模式共用同一套播放器界面、队列模型和后台播放；Server token 与小米会话分开保存。
纯播放器与直连共享本地歌单、收藏、队列、进度、音源和统计，不是两份独立曲库；Server 数据独立。
StoreEdition 不开放本地模式；Windows/Linux 未接本机音频后端时不开放纯播放器。设计见 [`14-direct-mode-migration-plan.md`](14-direct-mode-migration-plan.md)。

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
| 登录、队列、播放模式、当前曲目、目标设备（**Server 模式**） | HMusic-Server |
| 登录、队列、播放模式、当前曲目、目标设备（**直连模式**） | 本地仓库 `DirectPlaybackRepository` |
| 本机播放实时位置、缓冲、音频焦点、中断 | Flutter `AudioHandler` / `just_audio`（三模式共用同一 Handler） |
| 页面路由、筛选、弹层、临时输入 | Flutter UI |
| server base / 当前模式 | 本地配置，前后台音频进程共享 |
| 小米凭据（直连） | `flutter_secure_storage`，与 Server token 分开保存 |

Server 模式的本机播放每 3 秒调用 `/playback/local-report` 回写；播放结束以 `ended:true` 让服务端
推进队列，再消费返回的新 `streamUrl`。客户端不能在本地另造一套权威队列。

模式切换先暂停旧后端并保存进度，再释放本机音频、持久化新模式；切换带 generation 保护，
Handler 同时核对本机播放 epoch，拒绝旧命令与迟到的 `ended`。

## 4. 文档索引

| 文档 | 内容 |
|---|---|
| `01-architecture.md` | Flutter 工程结构、数据流、网络和状态边界 |
| `02-server-api.md` | API 契约、接入规则和已知缺口 |
| `03-design-system.md` | 内容品牌、组件、响应式与平台玻璃材质规则 |
| `04-screens.md` | 逐屏结构、交互与 API |
| `05-interactions-animations.md` | 动效、手势、快捷键 |
| `06-platform-native.md` | Flutter + Swift 平台壳、iOS/Android/桌面能力 |
| `07-roadmap.md` | P0-P7 验收路线、风险登记 |
| `08-audio-plugin.md` | Flutter 后台音频实现规格 |
| `09-p0-audit.md` | Server/App 审计基线、开放风险与当前出口门禁 |
| `10-engineering-standards.md` | MVVM、文件拆分、复用、依赖准入与 Code Review 门禁 |
| `11-release-compliance.md` | App Store/Google Play、隐私、内容权利、审核环境与签名 |
| `12-server-compatibility.md` | 当前 Server 契约缺口、兼容调用、重试和降级规则 |
| `13-ui-modernization-plan.md` | 全平台 UI 实施方案、分工与数据任务 |
| `14-direct-mode-migration-plan.md` | 直连模式设计、来源映射与验证记录 |
| `DEPLOYMENT.md` | 安装、放行与故障排查（面向用户） |
| `reviews/` | 逐轮评审与纠正记录（chrome、UI 现代化、播放与模式对照） |
| `decisions/ADR-0001-feature-first-mvvm.md` | 主架构冻结为 Feature-first MVVM |
| `decisions/ADR-0002-app-store-positioning.md` | NAS/家庭服务器个人音乐库产品定位与商店文案 |
| `decisions/ADR-0003-store-edition-demo-server-https.md` | 商店首发功能边界、Demo Server、公网 HTTPS/LAN HTTP 策略 |

## 5. 实现状态

**已交付（v0.1.9）**

- [x] 技术栈定案 Flutter，清理 Tauri 脚手架
- [x] P0 纵切：连接 → setup/login → 搜索 → 本机播放 → pause/seek → local-report → 后台下一曲
- [x] P1 核心播放器：完整播放页、沉浸歌词页、队列点播、设备切换、失效直链自救、冷启动续播
- [x] P2 全功能页：歌单、榜单（含 Spotify 统一契约）、统计图表、八区块设置、服务端下载、账户删除
- [x] 平台壳：iOS 26+ Swift/SwiftUI 液态玻璃 dock 与 mini 胶囊；Android/桌面
      `AdaptiveGlassSurface` 三档（高对比/减动效自动降为 off）
- [x] P7 直连模式：App 内小米登录、验证码与内嵌身份验证、设备发现、音源解析、本地队列与统计
- [x] P6/M1-M2：NAS 曲库扫描刮削、上传、`/library` API 与 App 曲库视图
- [x] P5 骨架：五平台 CI 发布矩阵、APK/AAB/IPA/DMG/EXE/tar.gz 可复现脚本、App 内更新与强升门

**进行中**

- [ ] P3 移动质量：双真机中断矩阵、锁屏长时、弱网恢复、性能与 GPU 基线、无障碍逐项验收
- [ ] P4 桌面原生：托盘与关窗驻留、窗口状态记忆、Windows/Linux 本机音频、SMTC/MPRIS
- [ ] P5 分发：签名公证、隐私政策与商店资料、HTTPS 审核 Demo Server、内容权利审查、
      TestFlight/Google closed test
- [ ] P7 真机实测：真实小米账号登录、音箱播放与双真机前后台/锁屏
- [ ] P6/M3 语音接管（Server conversation 轮询 + App 开关）

逐项门禁与开放风险见 [`09-p0-audit.md`](09-p0-audit.md)；阶段清单与勾选统计见
[`07-roadmap.md`](07-roadmap.md)。
