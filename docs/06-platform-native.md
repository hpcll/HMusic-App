# 06 - Flutter + Swift 平台能力

> 本章只记录 Flutter 平台接入要求。后台音频的业务状态机见 08。

## 1. 跨平台原则

- Dart 层定义 `PlatformServices` 小接口；仅确需原生 API 时使用插件或 platform channel。
- Flutter 内容 UI 不散落平台判断，差异集中在 `PlatformShellController` 与平台实现。
- 音频按钮、通知、锁屏面板、耳机事件都汇入同一个 `HMusicAudioHandler`。
- P0 优先保证 Android/iOS；桌面不得因未实现的托盘能力阻断编译和现有音箱遥控。
- 本机播放能力集中在 `ClientPlaybackCapabilities`：Android/iOS/macOS 可用，Windows/Linux
  尚未接入后端。后两者禁用本机选择与音源装载，保留既有 handler 和遥控链，不另造状态机。
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

**Impeller 决策（2026-09-04）**：AndroidManifest 曾全局关闭 Impeller（iQOO Z10 Turbo Pro /
骁龙 8s Gen 4 / Vulkan 上进出榜单详情整屏花屏，详见那里的注释）。小米 25019PNF3C
（天玑 9400 / Mali）真机 spike：进出榜单详情 ×10 零花屏、logcat 零 GPU 报错，
滚动帧 p95=2.38ms / max=3.73ms（120Hz 预算 8.33ms，0 帧超）——Impeller 保持开启，
TopEdgeScrim 渐进模糊因此在 Android 生效。**约束：iQOO（Adreno）复测通过前，
带此改动的构建不得进 release 发布**；若 Adreno 仍花屏，回退方案是
`ImpellerBackend=opengles` 或按 GPU 降级到 Medium。

**液态玻璃尝试（2026-09-04，已回退）**：曾以 `liquid_glass_renderer 0.2.0-dev.4`
（Impeller 专用真折射）上 dock/mini + 选中胶囊改 iOS 透镜亮泡，帧率无压力
（滚动 0 帧超预算），但真机评审**视觉不如常规毛玻璃**——亮色模式下白底白卡片
前的折射几乎不可见、整面发白发平，透镜亮泡过抢，所有者拍板回退。保留的教训：
①亮色暖纸底上液态玻璃天然吃亏，暗色才出效果，要做就分亮度定策略；
②暗色低 α 下边缘高光会抖动成点环，色散必须归零、玻璃色须抬亮；
③投影 DecoratedBox 记得带 borderRadius。若重启此方向，从暗色-only 起步。

具体 manifest/service 项以锁定版本的 `audio_service` 官方安装说明为准，不能凭旧模板手写类名。

## 3. iOS

P0 需要：

- Xcode 打开 Background Modes -> Audio, AirPlay, and Picture in Picture，确保 `audio` background mode。
- 音频会话使用 playback 类别，并处理 interruption、route change 和 becoming noisy。
- 访问局域网服务提供 `NSLocalNetworkUsageDescription`。
- 明文局域网按最小范围配置 ATS；优先 `NSAllowsLocalNetworking`，不得用全局任意加载作为默认方案。
- 锁屏 `MPNowPlayingInfoCenter` 与 remote command 由 audio_service 媒体会话驱动。

### iOS 26+ NativeGlassShell

- 当前代码在 iOS 26+ 使用 UIKit/SwiftUI 公开液态玻璃 API；本机可用 SDK 为 iOS 26.5。
  旧文档中的“iOS 27”不是实际运行门禁，不应据此禁用已支持的系统 dock。
- App 根部保持 FlutterViewController；展开态底栏由透明内容的原生 `UITabBarController`
  叠在 Flutter 上方，其根 view 铺满 Flutter window，由 UIKit 自行处理底部 safe area 与
  home indicator（禁止把 controller view 提前截到 safe-area 底边，否则系统会二次避让并裁切
  tab 标题）；完整采用系统 Liquid Glass 选择行为。SwiftUI 薄 overlay 当前承载 mini player
  和收缩圆钮；完整播放页及设备/音质 sheet 仍由 Flutter 实现，内容在其下方正常滚动。
- Swift 接收：导航摘要、曲目与 playing/outputLabel、主题与无障碍配置，
  以及 Flutter 算出的 mini 高度、缩放字号、allowMinimize；具体字段见第 7 节。
- Swift 回传：selectTab、openNowPlaying、openSearch、openOutputPicker、playPause、previous、next、seek、dismiss
  等语义 intent；点输出区域不能同时触发打开完整播放器。
- Swift 禁止持有 JWT、server base、队列或 Dio 等价网络实现；intent 必须回到 Dart
  `PlatformShellController`，再交给 Router/PlaybackCoordinator。
- 原生 shell 每次高度或安全区变化都通知 Flutter，内容 padding 同步更新，禁止遮挡列表末尾和按钮。
- 手机恢复 charts/playlists/stats/settings 四个 native id，显示为榜单/歌单/统计/设置。
  视口进入 rail/sidebar 时隐藏 native dock/mini，旋转及原生 ready 晚到也按当前视口同步。
- mini 恢复原两行，字号和高度由 Flutter 同时下发；空闲时保留“未在播放”占位。
  收起为左导航、中 mini、右搜索，移除额外的输出行和按钮；大字或宽度不足时不收缩。
  滚动遵循 UIKit `onScrollDown`：向下收起、向上展开；展开后主动报告 inset。
  不启用旧的不可达 SwiftUI 自绘 dock，不复制 UIKit 的选择手势。

回退策略：

1. iOS 26+ 且公开 Liquid Glass API 可用：UIKit 系统 dock 与 SwiftUI mini。
2. iOS <26 或原生能力不可用：Flutter 毛玻璃回退壳，保持同一导航和信息层级。
3. “降低透明度”开启或材质初始化失败：高对比不透明 surface。
4. “减少动态效果”开启：保留材质，关闭连续形变和跟手折射。

不得通过版本字符串强行调用不可用 API；必须使用编译期 availability 与运行时 capability 判断。

当前已接入 Bonjour 自动发现；iOS/macOS 声明 `_hmusic._tcp`，发现失败仍允许手输地址，详见 04。

## 4. 桌面

| 能力 | macOS | Windows | Linux | 阶段 |
|---|---|---|---|---|
| 普通窗口与音箱遥控 | Flutter，沿用现有 handler | Flutter；对应宿主待验收 | Flutter；对应宿主待验收 | 跨平台 UI；不以 widget 测试代替宿主验收 |
| 本机播放 | 现有 just_audio 平台实现 | 未接后端；UI 禁用本机选项 | 未接后端；UI 禁用本机选项 | Windows/Linux 后端后续单独实现与验收 |
| 媒体键/系统面板 | 现有平台媒体会话 | SMTC 待接入/验收 | MPRIS 待接入/验收 | P4 |
| 托盘 | system tray 插件或薄原生桥 | 同左 | 同左 | P4 |
| 窗口状态 | 独立轻量插件 | 同左 | 同左 | P4 |
| 开机自启 | 平台插件 | 平台插件 | desktop entry | P4 |

选择桌面音频后端前必须做 5 分钟 spike：三平台能 build、播放 HTTP Range 流、seek、输出设备切换。
未通过 spike 前，不在架构里承诺具体桌面插件。
锁定的 `audio_service_platform_interface` 在 Windows/Linux 使用 NoOpAudioService；缺少本机
后端不等于遥控初始化必然崩溃。本轮只为选择和装载加能力门禁，宿主遥控仍须实际验证。

## 5. 深链、通知与文件

- P0 不做深链和文件关联。
- 播放通知属于 audio_service 的媒体通知，不另发普通“切歌通知”打扰用户。
- 分享歌单链接先用粘贴输入；系统 Share Extension/Intent 放 P4 后评估。
- 下载管理使用已有 Server 能力；客户端入口统一叫“服务器下载”，明确保存到已连接的服务器，
  不承诺手机离线下载。

## 6. 安全

- JWT 存系统安全存储；server base 可存普通 preferences。
- 后台 AudioHandler 获取 token 必须走同一会话仓库，不复制成第二份明文配置。
- 调试日志对 Authorization、密码、小米凭据、音频签名路径做脱敏。
- server base 只允许 http/https，拒绝 credentials、query、fragment 与非空子路径。
- 修改 server base 时停止播放器并清理旧 token，避免把凭据发往新主机。
- Platform Shell 的 Dart/Swift channel 只传展示状态和语义 intent，禁止传 token、密码、音频签名 URL。
- 直连小米认证使用 Flutter 验证页内嵌的原生 WebView，显示普通 App 标题栏与关闭/刷新按钮；
  ViewModel 经 Cookie 适配器交接本次会话与受校验的 STS 回调。登录交换和安全保存仍在 Dart
  仓库，路由退出后按写入顺序清理临时 Cookie，不读系统浏览器数据，详见 14。
- App Store 构建只允许私有/本地地址使用 HTTP；公网地址必须 HTTPS 且证书有效，禁止跳过 TLS 校验。

## 7. Platform Shell 通道契约

P0 先冻结最小契约，字段使用可版本化 DTO，不传任意 Map：

```text
Dart -> Native
  shell.configure(version, darkMode, reduceMotion, reduceTransparency)
  shell.updateNavigation(selectedTab, title, canGoBack)
  shell.updateNowPlaying(trackId, title, artist, artworkUrl, playing, outputLabel)
  shell.updateLayout(showTabBar, showMiniPlayer, miniPlayerHeight, miniTitleFontSize,
                     miniDetailFontSize, allowMinimize)
  shell.updateScroll(minimized)

Native -> Dart
  shell.ready(capabilities)
  shell.layoutChanged(topInset, bottomInset)
  shell.intent(intent, value?)
```

- 通道未知字段向前兼容，未知 intent 忽略并记录脱敏日志。
- Native 未 ready 或崩溃时，Flutter 在同一帧树切换到 `AdaptiveGlassShell` 回退，应用不能白屏。
- SwiftUI Preview 只验视觉；真实通道、Flutter 合成和背景折射必须用 iOS 真机验收。
- 具体字段名与版本以 `platform_shell_bridge.dart` DTO 和 `NativeGlassShellChannel.swift` 为准；
  上表描述语义，不向 channel 传 Server 业务对象。新 Swift 文件必须登记 Xcode Sources。

## 验收

- [ ] Android/iOS 局域网 HTTP 首次授权文案清晰且可重试
- [ ] Android 前台服务通知和锁屏控制
- [ ] iOS 后台音频、锁屏信息与远程控制
- [ ] iOS 26+ 真机使用原生液态玻璃，旧 iOS/降低透明度自动回退
- [ ] Swift shell 与 Flutter 路由、mini player、媒体 intent 双向同步，无第二套业务状态
- [ ] Android High/Medium/Off 三档布局一致，长列表滚动无明显掉帧
- [ ] 原生 shell 不可用时 Flutter 回退壳可立即接管
- [ ] 来电/闹钟后按预期暂停或恢复
- [ ] 拔耳机立即暂停，不从扬声器外放
- [ ] Release 日志无敏感信息
