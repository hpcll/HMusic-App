# HMusic App 发布流程

## 发布前门禁

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --no-pub
```

版本号由 `pubspec.yaml` 的 `version` 决定，正式 tag 使用 `vX.Y.Z`，并与版本号保持一致。发布前确认
Server 的兼容版本、隐私政策、第三方声明和内容素材授权均已更新。

## Android

正式构建需要 `android/key.properties` 和 release keystore。该文件不会提交到仓库，格式如下：

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

本地没有密钥时可以执行 `bash tool/build_release.sh android` 验证编译，产物名会带 `-unsigned`，不能直接
安装或上传 Google Play。正式发布工作流设置 `HMUSIC_REQUIRE_RELEASE_SIGNING=true`，没有密钥时直接失败。

正式构建：

```bash
bash tool/build_release.sh android
```

`dist/` 会包含 APK、AAB 及各自的 SHA-256 文件。Google Play 使用 AAB，并启用 Play App Signing；APK
只用于可信渠道的直接安装或测试。

## Apple 与桌面平台

iOS 自签分发可以生成不含 Apple 签名的 IPA，供用户使用自己的 Apple ID/证书重签：

```bash
bash tool/build_release.sh ios-unsigned
```

产物为 `dist/hmusic-<版本>-ios-unsigned.ipa` 和对应的 SHA-256 文件。该包只能先导入自签工具重签，不能
直接安装，也不能替代 TestFlight/App Store 的正式签名包。发布说明必须明确这一点，并注明用户需要自行承担
证书有效期、设备注册和重新签名成本。

iOS/macOS 的 archive、签名、公证和 TestFlight/App Store 上传需要 Apple Developer 证书、profiles 和
App Store Connect 权限，不能在没有密钥的公开 CI 中完成。发布时应使用专用 CI secrets，并在签名机器上
验证后台音频、本地网络权限和系统媒体控制。

Windows/Linux 当前仍按路线图逐步补齐本机音频和安装包，未发布的平台不要在 Release 说明中承诺完整能力。
