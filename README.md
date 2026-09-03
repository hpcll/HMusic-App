# HMusic App

HMusic App 是连接自建 [HMusic-Server](https://github.com/hpcll/HMusic-Server) 的跨平台音乐客户端。
Server 管理曲库、搜索解析、队列和小爱音箱，App 负责搜索、播放、歌词、歌单和移动端后台播放。

它不是一个依赖开发者云账号的在线音乐服务：你在自己的 NAS、家庭服务器或电脑上部署一个 HMusic-Server，
然后让手机、平板和桌面端 App 连接它。音乐来源账号、播放队列、歌单、下载文件和播放历史都留在你自己的 Server 上。
同一个 Server 可以供家里的多个 App 使用，队列和小爱音箱状态是共享的；播放目标可以是手机本机，也可以是 Server 管理的小爱音箱。
同一时间使用“本机”播放时，建议只让一个 App 控制本机目标，避免多个客户端互相覆盖状态。

## 五分钟开始

### 1. 部署 HMusic-Server

在 NAS、Linux 服务器或长期开机的电脑上执行：

```bash
curl -fsSL https://raw.githubusercontent.com/hpcll/HMusic-Server/main/bootstrap.sh | bash
```

安装器会自动选择 Docker 或原生模式，启动后打印访问地址。用浏览器打开地址后面的 `/app/`，创建管理员账号，
然后在“设置 → 小米账号”登录并选择默认播放设备。完整的平台选择、升级和备份说明见
[Server 部署指南](https://github.com/hpcll/HMusic-Server/blob/main/docs/DEPLOYMENT.md)。

### 2. 安装 App

从 [HMusic App Releases](https://github.com/hpcll/HMusic-App/releases) 下载对应平台的包：

| 平台 | 下载文件 | 说明 |
| --- | --- | --- |
| Android | APK | 可直接安装；`-arm64-v8a` 适用近年所有手机（包最小），`-android.apk` 是含全部架构的通用包；AAB 用于 Google Play |
| iOS | `ios-unsigned.ipa` | 需要用自己的 Apple ID 或证书重签后安装 |
| macOS | `macos-universal.dmg` | 挂载后把 HMusic 拖进“应用程序”；同时支持 Apple Silicon 和 Intel |
| Windows | `windows-x64-setup.exe`（推荐）或 `windows-x64.zip` | 安装版带中文向导；ZIP 为便携版 |
| Linux | `linux-x64.tar.gz` | x86_64 便携版，内含应用图标 |

GitHub 连不上（或下载很慢）时，同一批包也在夸克网盘：
**<https://pan.quark.cn/s/c6534914a56b>**（每个版本一个目录，无提取码）。App 内“设置 → 关于与更新”
也常驻这条入口——检查更新能走国内镜像，但下载直链在 github.com 上，没有代理时走网盘更稳。

桌面端的包没有 Apple / 微软的付费签名，**首次打开一定会被系统拦一次，这是正常的**：

- macOS 提示“已损坏，应移到废纸篓”或“无法验证开发者”时，文件并没有坏。先双击一次，再到
  **系统设置 → 隐私与安全性** 点 **“仍要打开”**；或执行
  `xattr -dr com.apple.quarantine "/Applications/HMusic.app"`。macOS 15 起“右键打开”不再有效。
- Windows 弹“Windows 已保护你的电脑”时，点 **“更多信息 → 仍要运行”**；Edge 若在下载时就提示
  “已阻止不安全下载”，在下载列表里选择保留。

放行步骤、误报处理和 iOS 自签的完整说明见[安装与故障排查](docs/DEPLOYMENT.md)。每个 Release 附一个
`hmusic-<版本>-SHA256SUMS.txt`（所有平台的校验值都在里面），介意来源的话先核对再安装：

```bash
# 与包放在同一个目录下执行；Windows 用 certutil -hashfile <文件> SHA256 逐个比对
shasum -a 256 --ignore-missing -c hmusic-<版本>-SHA256SUMS.txt
```

### 3. 连接并登录

Server 部署完成后，App 首次启动会自动查找同一局域网内的 HMusic-Server。正常情况下你只需要点发现到的 Server，
不需要手工填写 IP。自动发现分两步进行：先使用局域网服务广播快速发现，未发现时再扫描本机网段的 `6650` 端口，
并通过 Server 身份接口确认结果。

如果列表为空，确认设备在同一局域网后点“重新扫描”；仍找不到时点“手动输入地址”，填写 Server 基础地址，例如：

```text
http://192.168.1.20:6650
```

不要填写 `/app/`，也不要把地址写成某个 API 路径。公网地址必须使用有效 HTTPS，局域网 HTTP 只适合可信网络。
连接后使用 Server 管理员账号登录；Server 尚未初始化时，App 会显示“创建并登录”。

换了 Wi-Fi 或 Server 的局域网地址后，重新打开连接页即可再次自动发现；也可以在“设置”中切换已保存的 Server。
iOS 首次使用必须允许 HMusic 访问“本地网络”，否则自动发现和局域网连接可能被系统拦截。

## 怎么用

1. **搜索歌曲**：进入“搜索”，输入歌名或歌手并提交。点击结果行的播放按钮立即播放，或加入队列/歌单。
2. **选择播放目标**：播放页的设备按钮可以选择“本机”或 Server 已配置的小爱音箱。选择音箱后，手机不会再占用本机音频会话。
3. **控制播放**：播放页支持播放/暂停、上一首/下一首、拖动进度、音量和播放模式；返回其他页面后可用底部 mini player 控制。
4. **看歌词**：有歌词的歌曲可从播放页进入歌词视图；歌词由 Server 按曲目来源获取并缓存。
5. **管理队列和歌单**：在队列页调整顺序和播放模式；歌单页可以创建、导入、播放歌单，也可以打开“NAS 曲库”浏览服务器上的本地音乐。
6. **下载到 Server**：搜索结果中的下载按钮会把有权限处理的音乐保存到 Server，完成后可在“设置 → 本地下载/NAS 曲库”中播放和管理。
7. **切换 Server 或设备**：在“设置”中切换已保存的 Server、刷新小米设备、修改默认播放设备和运行配置。

移动端支持后台播放、锁屏控制和播放结束后自动衔接下一曲。收到“登录已失效”提示时重新登录即可；这表示 Server 会话已过期，
不是本机音频故障。

## 当前平台边界

| 平台 | 已支持 | 当前限制 |
| --- | --- | --- |
| Android | 本机播放、后台播放、锁屏控制、小爱音箱遥控 | 正式商店包需要维护者配置 release 签名 |
| iOS | 本机播放、后台播放、锁屏控制、小爱音箱遥控 | Release 提供未签名 IPA；必须自行重签，不能直接安装 |
| macOS | 本机播放、系统媒体控制、小爱音箱遥控 | ad-hoc 包未做 Developer ID 公证；暂无托盘、关窗驻留和自动更新 |
| Windows | 连接 Server、管理内容、小爱音箱遥控 | 本机音频、SMTC、托盘和自动更新尚未完成 |
| Linux | 连接 Server、管理内容、小爱音箱遥控 | 本机音频、MPRIS、托盘和自动更新尚未完成 |

Windows/Linux 当前定位是桌面管理和远程控制端，不要把它们当作本机音乐播放器使用。平台能力和安装包以每个 Release 的说明为准。

## 网络与安全

- App 只连接你自己配置的 HMusic-Server；账号、播放历史和音乐数据由你的 Server 保存。
- iOS 首次连接需要允许“本地网络”权限；Android 请确认手机和 Server 在同一网络，且 TCP `6650` 未被防火墙拦截。
- 公网部署请使用 HTTPS 和反向代理；不要关闭证书校验，也不要把管理员密码、token 或小米会话发给第三方。
- Server 的 `.env`、`data/`、下载文件和音源插件是持久化数据，升级前请先备份。

## 文档与反馈

- [Server 项目与部署指南](https://github.com/hpcll/HMusic-Server)
- [安装与故障排查](docs/DEPLOYMENT.md)
- [最新发布包](https://github.com/hpcll/HMusic-App/releases)
- [安全问题报告](SECURITY.md)

## 请作者喝杯咖啡

HMusic App 和 HMusic-Server 都是免费开源的，没有会员、订阅和内购。如果它帮上了你，欢迎请作者喝杯咖啡～

<p align="center">
  <img src="docs/donate/wechat.jpg" alt="微信赞赏码" width="250" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/donate/alipay.jpg" alt="支付宝收款码" width="250" />
</p>

<p align="center">
  <b>微信赞赏</b>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <b>支付宝</b>
</p>

## 许可证

HMusic App 采用 [Apache License 2.0](LICENSE)。第三方依赖和声明见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。
