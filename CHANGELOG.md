# 更新日志

## Unreleased

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
