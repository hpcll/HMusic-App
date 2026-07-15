# HMusic App

HMusic 是 NAS/家庭服务器个人音乐库的官方跨平台客户端，面向 Android、iOS、macOS、Windows 与 Linux，
连接 [HMusic-Server](../HMusic-Server) 提供搜索、歌单、榜单、音箱遥控与本机播放。

视觉采用平台自适应方案：内容层延续现有 HMusic 网页的暖纸、墨色和衬线风格；iOS 27
由 Swift/SwiftUI 提供原生液态玻璃导航与控制层，Android 用 Flutter 实现接近且可降级的玻璃效果。

当前处于 **P0：最小纵切实现**。Flutter 工程、连接、鉴权、搜索和本机播放基础代码已经建立；
继续实现前先以 [`docs/09-p0-audit.md`](docs/09-p0-audit.md) 和
[`docs/12-server-compatibility.md`](docs/12-server-compatibility.md) 核对当前契约状态。

AI 编码代理进入仓库后必须先读 [`AGENTS.md`](AGENTS.md)，再按其中顺序读取架构、API、
路线图和任务专项文档。Claude、Gemini、Cursor、GitHub Copilot 的仓库入口文件均指向该规则，
避免维护多套指令。

## 文档入口

1. [00 总览](docs/00-overview.md) - 产品边界、技术栈与当前状态
2. [01 架构](docs/01-architecture.md) - Flutter 分层、状态所有权和目录
3. [02 API 契约](docs/02-server-api.md) - 服务端接口与客户端接入约束
4. [03 设计系统](docs/03-design-system.md) - HMusic 内容风格与 iOS/Android 玻璃材质规则
5. [04 逐屏说明](docs/04-screens.md) - 页面结构和交互
6. [05 交互动画](docs/05-interactions-animations.md) - 动效、快捷键和手势
7. [06 平台能力](docs/06-platform-native.md) - Flutter + Swift 平台壳、后台音频与系统配置
8. [07 路线图](docs/07-roadmap.md) - P0-P5 验收清单
9. [08 音频架构](docs/08-audio-plugin.md) - `audio_service` + `just_audio` 实现契约
10. [09 P0 审计](docs/09-p0-audit.md) - Server/App 事实核对、阻塞项和开工门禁
11. [10 工程规范](docs/10-engineering-standards.md) - MVVM、文件拆分、复用和依赖准入
12. [11 上架合规](docs/11-release-compliance.md) - App Store/Google Play、隐私、审核和签名门禁
13. [12 Server 兼容](docs/12-server-compatibility.md) - 契约缺口、兼容调用和重试规则

## 工程原则

- HMusic-Server 的 TypeScript 路由与共享 schema 是 API 事实源，文档不能替代运行契约。
- HMusic-Server/web 是产品行为和视觉参考，不再复制或嵌入客户端。
- Flutter 原生重写 UI；服务端是队列与语义播放状态的事实源，本机播放器是实时进度的事实源。
- 主架构冻结为 Feature-first MVVM；View、ViewModel、Repository 单向依赖，禁止巨型文件和万能层。
- 优先复用标准能力、现有代码和成熟依赖，不重复实现通用基础设施。
- 移动端后台播放是交付硬需求，不接受 WebView `<audio>` 或“仅遥控器”作为终态。
- 决策先更新文档，里程碑完成后回填状态。
