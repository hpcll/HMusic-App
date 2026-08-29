# 更新日志

## Unreleased

## 0.1.4 - 2026-08-29

- 修复 Android 正式包**一个插件都没注册**的发布脚本缺陷。`tool/build_release.sh` 先删掉生成的
  `GeneratedPluginRegistrant.java`，再用 `--no-pub` 构建；而这个文件只在 pub 步骤重新生成，
  `--no-pub` 恰好把这一步跳过，于是打出来的包里没有任何插件注册代码。FlutterEngine 找不到注册表
  只打一行 warning 就继续跑，所以包能装、能开、能连服务端、能拉列表，但插件通道全是空的：
  - 点任何一首歌都报 `MissingPluginException(... audio_service.client.methods)`——本机曲库和
    音源直链一样播不了，同一台服务端的网页端却正常（网页端不经过 App 插件）；
  - 安全存储写不进去，token 只活在内存里，于是「每次打开都要重新登录」；
  - 本地键值存储同样失效——0.1.2 记的 `SharedPreferencesAsync channel-error` 是同一个根因，
    之前两次「失败就降级」的兜底只把它藏得更深。
  现在构建不再跳过 pub（release 模式的 pub 自己会剔除 integration_test 这类 dev 依赖插件，
  手删文件本就没必要），并在打包后机械校验注册表内容与 APK 里确有注册代码，缺一样就构建失败。
- 冷启动接续上次连接的服务器：开屏直接连回去并进入登录页，token 有效就继续放行到首页，不再每次
  都要从「附近的服务器」重新点一台——点到的地址形态（mDNS 给 `host.local`、扫段给 IP）与上次存的
  不一致时会被当成换了服务器而清掉 token，这是「每次打开要重新登录」的另一条路径。接续失败
  （换了网络、服务端没开机）静默回落到自动扫描，不打扰用户。
- 修复部分机型进出榜单详情时**整屏花屏一下**：画面在状态栏以下被横向重复约 4 次，约 100ms 后自愈，
  进入和返回两个方向都会出现，但不是必现，也只在部分设备上出现。用三个只差一处的诊断包实测定位到
  Impeller(Vulkan) 后端本身——只关掉顶缘的 shader 渐进模糊仍然花，关掉 Impeller 就干净
  （iQOO Z10 Turbo Pro / 骁龙 8s Gen 4 / Android 16，来回切 10 次零复现）。Android 因此改回 Skia
  渲染后端。代价是顶缘渐进模糊在 Android 上退成同色纱帘（依旧无缝，只是没有磨砂）；根因大概率在
  引擎/驱动侧，升级 Flutter 引擎后会重新实测，能不花就换回 Impeller。

## 0.1.3 - 2026-08-28

- 修复登录页卡在「处理中…」：钥匙串/Keystore 通道失效时 `SecureTokenStore` 的异常会整个逃出
  提交流程，把状态永久留在 submitting。现在写不进持久层只降级为本次会话驻留内存，登录与连接
  流程还额外加了兜底捕获——任何意外都会退出忙碌态并报出原因，不再冻住按钮。
- README 与安装文档补齐 macOS/Windows 未签名包的放行步骤：说明“已损坏，应移到废纸篓”只是 Gatekeeper
  的措辞，并纠正 macOS 15 起“右键打开”已失效、须走系统设置的变化。

## 0.1.2 - 2026-08-28

- 修复部分 Android 机型「能发现服务端但连接报错」：本地键值存储在 `SharedPreferencesAsync`
  的 DataStore 通道失效（`PlatformException: channel-error`）时自动降级到 legacy
  SharedPreferences，两级都不可用则退到进程内内存。保存服务器地址、升级缓存和本机音量
  不再因为本地存储故障中断连接流程。
- Android 构建号（versionCode）开始随发版递增：`pubspec.yaml` 的版本改为 `0.1.2+2`，
  此前所有包的 versionCode 都固定是 1。

## 0.1.1 - 2026-08-28

- 准备公开发布的安装、贡献、安全和构建文档。
- 增加 Android APK/AAB 的可复现构建脚本与 SHA-256 校验文件。
- 增加 Windows x64 中文安装向导，支持开始菜单、可选桌面快捷方式和卸载。
- Linux 便携包加入应用图标和桌面入口资源。

版本发布时将记录兼容性变化、迁移步骤和已知限制。版本号遵循 `pubspec.yaml` 与 Git tag 对齐的规则。
