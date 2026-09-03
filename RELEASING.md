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

`dist/` 会包含 APK、AAB，以及一个汇总所有产物校验值的 `hmusic-<版本>-SHA256SUMS.txt`（一版一个文件，
同一台机器上再构建别的平台会把新行 upsert 进去，不再是每个包各带一个 `.sha256`）。Google Play 使用 AAB，
并启用 Play App Signing；APK 只用于可信渠道的直接安装或测试。

Android 侧一次出四个 APK：

| 产物 | 用途 |
|---|---|
| `hmusic-<版本>-android.apk` | 通用包（含全部架构，~61MB）：手动下载、以及 App 挑不到本机架构时的回落 |
| `hmusic-<版本>-android-arm64-v8a.apk` | 近年所有手机（~25MB）：App 内自更新实际下的就是它 |
| `hmusic-<版本>-android-armeabi-v7a.apk` | 32 位老机（~22MB） |
| `hmusic-<版本>-android-x86_64.apk` | 模拟器 / x86 平板（~26MB） |

架构段的写法（`arm64-v8a` / `armeabi-v7a` / `x86_64`）是 App 挑包的依据
（`api_update_repository._pickApkAsset` 按 `-<abi>.` 整段匹配），**改名要同步改那里**。
发布工作流按 `dist/*-android*.apk` 收集，分包会自动跟着上 Release。

发 Release 之后顺手更新仓库根的 `app-config.json`（三镜像 + 服务端中转，见 docs/02）：

```json
{
  "latestVersion": "v0.1.6",
  "apkUrl": "https://github.com/.../hmusic-0.1.6-android.apk",
  "apkSize": 61266359,
  "netdiskUrl": "https://pan.quark.cn/s/c6534914a56b"
}
```

`netdiskUrl` 是没梯子用户的退路（关于页常驻那条「从网盘下载」）：检查更新能靠 Gitee 镜像绕开
GitHub，下载直链却在 github.com 上。换网盘链接改这里即可，不用发新版；App 内置了同一条链接兜底
（`kNetdiskDownloadUrl`），所以连 app-config 都拉不到时入口仍在。

App 的「检查更新」优先问 `api.github.com`，拉不到（大陆不通、代理出口被限流 403）就退到这份文件；
不填这三个字段，那条退路等于不存在，用户只会看到 GitHub 的失败原因。`minVersion` 仍是强制升级门，
只在需要召回旧版本时才抬高。

## Apple 与桌面平台

iOS 自签分发可以生成不含 Apple 签名的 IPA，供用户使用自己的 Apple ID/证书重签：

```bash
bash tool/build_release.sh ios-unsigned
```

产物为 `dist/hmusic-<版本>-ios-unsigned.ipa`，校验值写入同目录的 `hmusic-<版本>-SHA256SUMS.txt`。该包只能先导入自签工具重签，不能
直接安装，也不能替代 TestFlight/App Store 的正式签名包。发布说明必须明确这一点，并注明用户需要自行承担
证书有效期、设备注册和重新签名成本。

iOS/macOS 的 archive、签名、公证和 TestFlight/App Store 上传需要 Apple Developer 证书、profiles 和
App Store Connect 权限，不能在没有密钥的公开 CI 中完成。发布时应使用专用 CI secrets，并在签名机器上
验证后台音频、本地网络权限和系统媒体控制。

桌面包：

```bash
bash tool/build_release.sh macos-adhoc
bash tool/build_release.sh linux
```

macOS 产物是 `hmusic-<版本>-macos-universal.dmg`：ad-hoc 签名的 universal `HMusic.app` 加一个
“应用程序”软链，用户挂载后拖过去即可安装（0.1.5 起取代原来的 `-macos-universal-adhoc.zip`）。

Windows 在 PowerShell 中执行（需要安装 Inno Setup 6，并确保 `ISCC.exe` 在 PATH 中）：

```powershell
./tool/build_windows_release.ps1
```

脚本会从 Inno Setup 官方仓库的固定提交获取简体中文语言文件，并在编译前校验 SHA-256；构建机需要能访问
`raw.githubusercontent.com`。

Windows 构建会同时生成便携 ZIP 和真正的安装向导 EXE：

- `hmusic-<版本>-windows-x64-setup.exe`：中文安装向导，默认按当前用户安装到
  `%LocalAppData%\Programs\HMusic`，创建开始菜单入口，可选桌面快捷方式，并提供卸载入口。
- `hmusic-<版本>-windows-x64.zip`：无需安装的便携包，适合临时使用或受限环境。

校验值统一进 `hmusic-<版本>-SHA256SUMS.txt`：各平台的构建脚本在本机 `dist/` 里 upsert 自己那几行，
CI 里则由 `checksums` job 汇总所有平台的包重新生成一份，并与 Release 上已有的同名文件合并——所以
`scope: desktop` 之类的局部重跑不会抹掉其他平台的校验值。最终 Release 是 7 个包 + 1 个校验文件。

macOS 包未经 Developer ID 签名与公证，Windows 安装包和便携包均未经
Authenticode 签名；Release 必须提示系统安全警告和当前桌面功能边界。

Windows/Linux 当前仍按路线图逐步补齐本机音频和系统集成，Release 说明不得承诺尚未实现的能力。
