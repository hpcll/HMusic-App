# 更新日志

## Unreleased

- 修复部分 Android 机型「能发现服务端但连接报错」：本地键值存储在 `SharedPreferencesAsync`
  的 DataStore 通道失效（`PlatformException: channel-error`）时自动降级到 legacy
  SharedPreferences，两级都不可用则退到进程内内存。保存服务器地址、升级缓存和本机音量
  不再因为本地存储故障中断连接流程。

## 0.1.1 - 2026-08-28

- 准备公开发布的安装、贡献、安全和构建文档。
- 增加 Android APK/AAB 的可复现构建脚本与 SHA-256 校验文件。
- 增加 Windows x64 中文安装向导，支持开始菜单、可选桌面快捷方式和卸载。
- Linux 便携包加入应用图标和桌面入口资源。

版本发布时将记录兼容性变化、迁移步骤和已知限制。版本号遵循 `pubspec.yaml` 与 Git tag 对齐的规则。
