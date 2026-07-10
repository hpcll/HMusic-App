# HMusic Desktop

HMusic 的官方跨平台客户端 —— **Tauri 2.x 壳 + 复用 [HMusic-Server](../HMusic-Server) 的 web/ 前端**。
一套代码出 macOS / Windows / Linux / iOS / Android，视觉与网页端 1:1。

## 快速开始

```bash
# 前置：Rust + Node；HMusic-Server 仓库在同级目录
bash scripts/sync-web.sh   # 从 ../HMusic-Server/web 同步前端
cargo tauri dev            # 开发窗口
cargo tauri build          # 打包当前平台
```

首次启动 → 填服务器地址（如 `http://192.168.1.10:8090`）→ 登录 HMusic 账号。

## 文档（先读这里再写代码）

一切设计与实现决策都在 [`docs/`](docs/00-overview.md)：

1. [00 总览](docs/00-overview.md) —— 项目定位、技术选型、里程碑
2. [01 架构](docs/01-architecture.md) —— 目录、Tauri 配置、web 同步策略、四大核心决策
3. [02 API 契约](docs/02-server-api.md) —— 后端全量端点
4. [03 设计系统](docs/03-design-system.md) —— token/组件/动效（1:1 复刻依据）
5. [04 逐屏说明](docs/04-screens.md) —— 每屏结构、交互、调用的 API
6. [05 交互动画](docs/05-interactions-animations.md) —— 既有语言 + 桌面/移动增强
7. [06 原生能力](docs/06-platform-native.md) —— 托盘/媒体键/后台播放
8. [07 路线图](docs/07-roadmap.md) —— 里程碑验收清单 + 风险登记

## 铁律

- **UI 代码的事实源是 HMusic-Server/web**，本仓库只写 `src/native/`（渐进增强层）与 Rust 壳。
- 改 UI → 去 Server 仓库改 → `sync-web.sh` 同步回来。禁止直接改同步产物。
- 文档先行：决策变更先改 docs 再改代码。
