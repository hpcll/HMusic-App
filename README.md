# HMusic App

HMusic 是连接自建 [HMusic-Server](https://github.com/hpcll/HMusic-Server) 的跨平台音乐库客户端，
面向 Android、iOS、macOS、Windows 与 Linux。服务端保存曲库、队列和账号状态，客户端负责内容展示、
本机播放、后台播放和家庭音箱控制。

## 快速开始

### 1. 部署 Server

在 NAS、Linux 服务器或长期开机的电脑上执行：

```bash
curl -fsSL https://raw.githubusercontent.com/hpcll/HMusic-Server/main/bootstrap.sh | bash
```

安装器会自动选择 Docker 或原生模式，并打印访问地址。打开 `/app/` 创建管理员账号，完成服务端初始化。
Linux NAS 推荐 Docker host network；macOS 和 Windows Docker Desktop 推荐原生模式。完整说明见
[Server 部署文档](https://github.com/hpcll/HMusic-Server/blob/main/docs/DEPLOYMENT.md)。

### 2. 安装 App

从 [Releases](https://github.com/hpcll/HMusic-App/releases) 下载对应平台的构建包。首次启动输入 Server 地址，
例如 `http://192.168.1.20:6650`，然后使用刚创建的账号登录。

公网部署必须使用有效 HTTPS；局域网 HTTP 只适合可信网络。iOS 首次连接时允许“本地网络”权限，Android
需要确保手机和 Server 在同一网络且端口 `6650` 未被防火墙拦截。

## 当前支持范围

| 平台 | 当前状态 | 发布形式 |
| --- | --- | --- |
| Android | 本机播放、后台播放、锁屏控制 | APK / Google Play AAB |
| iOS | 本机播放、后台播放、锁屏控制 | 可自签 IPA / TestFlight / App Store |
| macOS | 本机播放、系统媒体控制；未做托盘/关窗驻留 | universal ad-hoc ZIP |
| Windows | 服务端和音箱遥控；本机音频/SMTC 未完成 | x64 便携 ZIP |
| Linux | 服务端和音箱遥控；本机音频/MPRIS 未完成 | x64 便携 tar.gz |

Windows/Linux 的本机音频、托盘和系统媒体集成仍在路线图中；macOS 已支持本机播放和系统媒体控制，请以每次
Release 的说明为准。

## 开发

需要 Flutter stable、Dart SDK `^3.9.2` 和可用的 Android/iOS/macOS 工具链：

```bash
flutter pub get
flutter analyze
flutter test
```

Android 发布包：

```bash
bash tool/build_release.sh android
```

输出位于 `dist/`，同时生成 APK、AAB 和 SHA-256 校验文件。正式商店发布仍需要维护者配置签名密钥，
详见 [贡献指南](CONTRIBUTING.md) 和 [发布说明](RELEASING.md)。

iOS 自签 IPA（需要 macOS 和 Xcode，只构建不签名）：

```bash
bash tool/build_release.sh ios-unsigned
```

输出 `dist/hmusic-<版本>-ios-unsigned.ipa`。该包没有 Apple 描述文件，不能直接安装；使用自己的 Apple ID
或开发者证书导入 AltStore、SideStore、Sideloadly 等工具重签后再安装。完整步骤见
[安装与故障排查](docs/DEPLOYMENT.md)。

macOS 与 Linux 发布包：

```bash
bash tool/build_release.sh macos-adhoc  # 仅 macOS
bash tool/build_release.sh linux        # 仅 Linux x64
```

Windows x64 发布包在 PowerShell 中构建：

```powershell
./tool/build_windows_release.ps1
```

macOS 产物同时包含 Apple Silicon 与 Intel 架构，使用 ad-hoc 签名但未做 Developer ID 公证。Windows/Linux
当前是完整 UI 和远端控制便携包，本机音频与系统媒体面板仍在 P4 范围内。

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

安装、连接或播放异常时，先查看 [故障排查](docs/DEPLOYMENT.md)。参与开发请阅读
[CONTRIBUTING.md](CONTRIBUTING.md)，安全问题请按 [SECURITY.md](SECURITY.md) 报告。

## 工程原则

- HMusic-Server 的 TypeScript 路由与共享 schema 是 API 事实源，文档不能替代运行契约。
- HMusic-Server/web 是产品行为和视觉参考，不再复制或嵌入客户端。
- Flutter 原生重写 UI；服务端是队列与语义播放状态的事实源，本机播放器是实时进度的事实源。
- 主架构冻结为 Feature-first MVVM；View、ViewModel、Repository 单向依赖，禁止巨型文件和万能层。
- 优先复用标准能力、现有代码和成熟依赖，不重复实现通用基础设施。
- 移动端后台播放是交付硬需求，不接受 WebView `<audio>` 或“仅遥控器”作为终态。
- 决策先更新文档，里程碑完成后回填状态。
