# 06 - Flutter + Swift 平台能力

> 本章只记录 Flutter 平台接入要求。后台音频的业务状态机见 08。

## 1. 跨平台原则

- Dart 层定义 `PlatformServices` 小接口；仅确需原生 API 时使用插件或 platform channel。
- Flutter 内容 UI 不散落平台判断，差异集中在 `PlatformShellController` 与平台实现。
- 音频按钮、通知、锁屏面板、耳机事件都汇入同一个 `HMusicAudioHandler`。
- P0 优先保证 Android/iOS；桌面不得因未实现的托盘能力阻断编译和普通播放。
- Swift/SwiftUI 只负责 iOS 系统 chrome 和材质，不访问 Server，不复制 Flutter 业务状态。

## 2. Android

P0 需要：

- `android.permission.INTERNET`。
- 局域网明文 HTTP：显式允许 cleartext；发布前再提供 HTTPS 优先提示。
- 后台播放前台服务及媒体通知，声明 `FOREGROUND_SERVICE`、媒体播放类型所需权限；
  Android 13+ 处理通知权限，Android 14+ 校验 `mediaPlayback` service type。
- 音频焦点、耳机拔出、蓝牙切换由 `audio_session`/播放器事件处理。
- release 验证锁屏 30 分钟、Doze、应用切走和进程被系统回收后的可预测行为。

### Android 液态玻璃近似层

Android 默认由 Flutter `AdaptiveGlassSurface` 实现，与 iOS 保持相同布局、语义和触摸目标，
不强求复制苹果私有材质物理。允许后续在确有收益时用薄 Kotlin/RenderEffect 桥优化，但 P0 不预建。

| 档位 | 效果 | 启用条件 |
|---|---|---|
| High | 动态 BackdropFilter、背景采样、高光和轻微形变 | 高性能设备、非省电、未降低动画/透明度 |
| Medium | 较低 blur、静态高光、无持续背景采样 | 默认档，普通设备 |
| Off | 不透明/半透明 panel、边框和阴影，无实时 blur | 低性能、省电、降低透明度或检测到掉帧 |

- 三档的尺寸、排版、导航位置必须完全一致，降级不能造成布局跳动。
- 连续滚动时以稳定帧时间优先；若玻璃导致明显掉帧，自动降一级而不是降低内容刷新率。
- 列表项和内容卡片禁止逐项 BackdropFilter，只允许 app chrome 使用共享模糊层。

具体 manifest/service 项以锁定版本的 `audio_service` 官方安装说明为准，不能凭旧模板手写类名。

## 3. iOS

P0 需要：

- Xcode 打开 Background Modes -> Audio, AirPlay, and Picture in Picture，确保 `audio` background mode。
- 音频会话使用 playback 类别，并处理 interruption、route change 和 becoming noisy。
- 访问局域网服务提供 `NSLocalNetworkUsageDescription`。
- 明文局域网按最小范围配置 ATS；优先 `NSAllowsLocalNetworking`，不得用全局任意加载作为默认方案。
- 锁屏 `MPNowPlayingInfoCenter` 与 remote command 由 audio_service 媒体会话驱动。

### iOS 27 NativeGlassShell

- iOS 27 目标 SDK 可用时，Swift/SwiftUI 使用系统公开的液态玻璃材质和控件 API；具体类型名在
  工程使用的 Xcode SDK 中确认，文档不预写未经编译验证的私有或猜测 API。
- App 根部保持 FlutterViewController；展开态底栏由透明内容的原生 `UITabBarController`
  叠在 Flutter 上方，其根 view 铺满 Flutter window，由 UIKit 自行处理底部 safe area 与
  home indicator（禁止把 controller view 提前截到 safe-area 底边，否则系统会二次避让并裁切
  tab 标题）；完整采用系统 Liquid Glass 选择行为；SwiftUI 薄 overlay 只承载 mini player、
  收缩圆钮、播放控制面板与系统 sheet，Flutter 内容在其下方正常滚动。
- Swift 接收：selectedTab、pageTitle、nowPlaying 摘要、playbackState、controls、theme、accessibility。
- Swift 回传：selectTab、openNowPlaying、playPause、previous、next、seek、dismiss 等语义 intent。
- Swift 禁止持有 JWT、server base、队列或 Dio 等价网络实现；intent 必须回到 Dart
  `PlatformShellController`，再交给 Router/PlaybackCoordinator。
- 原生 shell 每次高度或安全区变化都通知 Flutter，内容 padding 同步更新，禁止遮挡列表末尾和按钮。

回退策略：

1. iOS 27 且公开 Liquid Glass API 可用：真实系统材质。
2. 较旧 iOS：SwiftUI 系统 material/blur，保持相同结构。
3. “降低透明度”开启或材质初始化失败：高对比不透明 surface。
4. “减少动态效果”开启：保留材质，关闭连续形变和跟手折射。

不得通过版本字符串强行调用不可用 API；必须使用编译期 availability 与运行时 capability 判断。

若未来加入 Bonjour 自动发现，再单独声明服务类型；P0 手输地址不需要伪造 Bonjour 配置。

## 4. 桌面

| 能力 | macOS | Windows | Linux | 阶段 |
|---|---|---|---|---|
| 普通窗口与本机播放 | Flutter + 经验证的 just_audio 平台实现 | 同左 | 同左 | P1 前保持可编译，P4 完整验收 |
| 媒体键/系统面板 | 平台媒体会话 | SMTC | MPRIS | P4 |
| 托盘 | system tray 插件或薄原生桥 | 同左 | 同左 | P4 |
| 窗口状态 | 独立轻量插件 | 同左 | 同左 | P4 |
| 开机自启 | 平台插件 | 平台插件 | desktop entry | P4 |

选择桌面音频后端前必须做 5 分钟 spike：三平台能 build、播放 HTTP Range 流、seek、输出设备切换。
未通过 spike 前，不在架构里承诺具体桌面插件。

## 5. 深链、通知与文件

- P0 不做深链和文件关联。
- 播放通知属于 audio_service 的媒体通知，不另发普通“切歌通知”打扰用户。
- 分享歌单链接先用粘贴输入；系统 Share Extension/Intent 放 P4 后评估。
- 下载管理 API 已稳定，客户端入口按路线图排到 P2。

## 6. 安全

- JWT 存系统安全存储；server base 可存普通 preferences。
- 后台 AudioHandler 获取 token 必须走同一会话仓库，不复制成第二份明文配置。
- 调试日志对 Authorization、密码、小米凭据、音频签名路径做脱敏。
- server base 只允许 http/https，拒绝 credentials、query、fragment 与非空子路径。
- 修改 server base 时停止播放器并清理旧 token，避免把凭据发往新主机。
- Dart/Swift channel payload 只传展示状态和语义 intent，禁止传 token、密码、音频签名 URL。
- App Store 构建只允许私有/本地地址使用 HTTP；公网地址必须 HTTPS 且证书有效，禁止跳过 TLS 校验。

## 7. Platform Shell 通道契约

P0 先冻结最小契约，字段使用可版本化 DTO，不传任意 Map：

```text
Dart -> Native
  shell.configure(version, theme, reduceMotion, reduceTransparency)
  shell.updateNavigation(selectedTab, title, canGoBack)
  shell.updateNowPlaying(trackId, title, artist, artworkUrl, state, controls)
  shell.updateLayout(showMiniPlayer)

Native -> Dart
  shell.ready(capabilities, topInset, bottomInset)
  shell.layoutChanged(topInset, bottomInset)
  shell.intent(type, value?)
```

- 通道未知字段向前兼容，未知 intent 忽略并记录脱敏日志。
- Native 未 ready 或崩溃时，Flutter 在同一帧树切换到 `AdaptiveGlassShell` 回退，应用不能白屏。
- SwiftUI Preview 只验视觉；真实通道、Flutter 合成和背景折射必须用 iOS 真机验收。

## 验收

- [ ] Android/iOS 局域网 HTTP 首次授权文案清晰且可重试
- [ ] Android 前台服务通知和锁屏控制
- [ ] iOS 后台音频、锁屏信息与远程控制
- [ ] iOS 27 真机使用原生液态玻璃，旧 iOS/降低透明度自动回退
- [ ] Swift shell 与 Flutter 路由、mini player、媒体 intent 双向同步，无第二套业务状态
- [ ] Android High/Medium/Off 三档布局一致，长列表滚动无明显掉帧
- [ ] 原生 shell 不可用时 Flutter 回退壳可立即接管
- [ ] 来电/闹钟后按预期暂停或恢复
- [ ] 拔耳机立即暂停，不从扬声器外放
- [ ] Release 日志无敏感信息
