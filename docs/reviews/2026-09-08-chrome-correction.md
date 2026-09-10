# 2026-09-08 · 底部外壳纠正与测试包

用户明确要求保留既有 dock、mini 播放器外观，并提供 Apple Music 展开与收起截图作为动画参考。
本轮恢复手机底部外观，保留已完成的榜单分类横移及其他独立内容改动。

## 行为与范围

- dock 恢复原来的榜单 / 歌单 / 统计 / 设置四项，以及原图标、玻璃材质、选中胶囊与 62 基础高度。
- mini 恢复基础高 50 的封面、曲名/歌手、播放和下一首；设备选择回到完整播放器。
  空闲时显示“未在播放”，禁用播控。大字号按两行实际高度增高，2 倍字为 79。
- 收起为左侧当前导航圆钮、中间 mini、右侧搜索。mini 收窄下落时，歌手与下一首同步让位。
  选中图标沿单一路径移动，消除交叉淡化造成的图标重影。
- 滚动采用 UIKit `UITabBarMinimizeBehaviorOnScrollDown` 的公开语义：向下收起、向上展开。
  横向分类滚动不影响底栏；点导航圆钮只展开，搜索沿用现有覆盖页。
- 普通 320/360/430 宽手机可收起；字号超过 1.2 倍或中央 mini 宽度不足 160 时保留展开态。
- 榜单分类点选后用最近的横向 ScrollPosition 将选中项移向中间，露出相邻分类；页面纵向位置保持稳定。
  分类过渡 220ms，底部形变 320ms easeOutCubic，减动效立即定位。

外壳统一提供一条收纳进度，导航、mini 和搜索共享；播放动作继续通过现有 PlayerViewModel，
保持 KISS/DRY 与状态单一来源。桌面播放条、曲库/NAS 与服务端播放业务沿用现有实现。

## 验证

- `dart format .`：414 个 Dart 文件格式化完成。
- `flutter analyze --no-pub`：零问题。
- 全仓 `flutter test --no-pub` 加可选外壳截图用例：419 项通过（基础 414 项 + 5 项视觉用例）。
- 外壳用例覆盖首项/末项/统计入口、窄屏几何、反向打断、空闲状态、播控/搜索点击、大字与减动效。
- 视觉截图使用真实 `FlutterGlassShell`、`AppBottomNav`、`MiniPlayer` 与离线列表数据，
  覆盖浅色、深色、空闲、320 窄屏与 2 倍字；展开/收起各检查 21 帧。
- Swift 外壳语法检查与 iOS Simulator SDK 独立类型检查通过；原有 `traitCollectionDidChange`
  弃用警告仍存在。
- `git diff --check` 通过。

本次截图用于验证布局端点及 Flutter 过渡；用户提供的是静态参考，320ms 曲线属于近似实现。
当前没有连接手机，Android 真机动画手感、iOS 实际宿主合成与原生材质仍待复验。
本轮未修改后台音频链路，不将组件检查当作后台/锁屏真机验收。

## 测试包与交付

构建命令：

```sh
flutter build apk --release --target-platform android-arm64 --build-number 2009 --dart-define=HMUSIC_STORE_EDITION=false
```

- 文件：`dist/HMusic-0.1.7-charts-test-2009-arm64.apk`，25,171,385 bytes。
- 包名 `com.hupc.hmusic`；versionName `0.1.7`，versionCode `2009`。
- SHA256：`65f13e8b9df6b6a5b9098126ca746ef571a003e630d567f991a4db790d33c8fc`。
- 签名与 2008 一致，可覆盖安装；证书 SHA256 为
  `e032ed86248e73e2affdcdf3c4902464a92c98baddba4a57852a59f5da15570d`。
- ZIP 完整性及 ARM64 Flutter runtime 已检查，Dart AOT 内容与 2008 不同。
  其他架构仅含 datastore 依赖库，分布与 2008 一致。
- 注册表包含 audio_service、just_audio、audio_session、secure storage、preferences 和 Bonsoir，
  APK 中保留 audio_service 注册路径，未混入 IntegrationTestPlugin。
- 飞书文件消息 `om_x100b66ce56ce50b0b3ec20e51ad0e27` 已回读，文件名匹配且未删除。
  [消息链接](https://applink.feishu.cn/client/chat/open?openChatId=oc_815bd86bdcc41907143b18056b3928a9&position=35)。

原始截图、测试日志及包验证记录位于本机 `/tmp/hmusic-charts-review/`。

## Spotify 条件

当前 App 没有原生 Spotify 登录页。Spotify 连接仍在服务端 Web 设置中；App 根据 `/charts`
返回的 Spotify 个人榜/公开榜展示内容，商店版另受 StoreEdition 限制。
公开服务端最新版 v0.2.3 不包含本轮尚未发版的统一榜单接口；显示这些榜单需要包含该接口的
服务端版本、已连接的 Spotify 账号，以及 App 刷新。本轮未发布或升级服务端。
