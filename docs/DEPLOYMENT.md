# App 安装与故障排查

## 连接流程

1. 部署并启动 [HMusic-Server](https://github.com/hpcll/HMusic-Server)。
2. 在浏览器打开 Server 的 `/app/`，创建管理员账号并完成初始化。
3. 将手机、平板或电脑与 Server 放在同一局域网，安装 HMusic App。连接页会自动发现并验证 HMusic-Server，点选对应条目即可连接。
4. 如果自动发现没有结果，点“重新扫描”；仍然找不到时选择“手动输入地址”，填写 Server 基础地址，不要填写 `/app/` 路径。
5. 登录后执行一次搜索和播放，确认服务端与本机播放链路都正常。

Server 默认端口为 `6650`。例如 Server 地址是 `http://192.168.1.20:6650`，App 中也填写这个地址。

## iOS 自签安装

Release 中的 `hmusic-<版本>-ios-unsigned.ipa` 是面向自签的未签名包，不能在 iPhone 上直接点开安装。请准备
自己的 Apple ID 或 Apple Developer 证书，并使用 AltStore、SideStore、Sideloadly 等重签工具：

1. 将 IPA 导入工具，选择自己的 Apple ID/签名证书和目标 iPhone。
2. 让工具完成重签并安装；首次安装若出现信任提示，在“设置 > 通用 > VPN 与设备管理”中信任对应开发者。
3. 打开 HMusic，填入自己的 HMusic-Server 地址并登录。

自签应用受 Apple 证书有效期和设备数量限制，过期后需要用同一工具重新签名；这不是 HMusic 的应用内更新机制。
IPA 的 Bundle ID 为 `com.hupc.hmusic`，重签工具通常会自动处理嵌套 Flutter framework 的签名。

维护者在 macOS 上生成同类包：

```bash
bash tool/build_release.sh ios-unsigned
shasum -a 256 dist/hmusic-*-ios-unsigned.ipa
```

脚本会验证主 App 没有签名或 `embedded.mobileprovision`，并将 App 放入标准 `Payload/HMusic.app` 目录。

## 桌面端安装

### macOS

下载 `hmusic-<版本>-macos-universal.dmg`，双击挂载后把 `HMusic` 拖到窗口里的“应用程序”快捷方式上，
然后推出磁盘映像即可删除 dmg。该包同时支持
Apple Silicon 与 Intel，使用 ad-hoc 签名但没有 Developer ID 公证，所以首次打开一定会被系统拦下，
提示“无法验证开发者”，或者——**从浏览器下载时更常见的——“已损坏，应移到废纸篓”**。这句话是
Gatekeeper 对“未公证 + 带下载隔离标记”的措辞，文件本身没有损坏，可以对照 Release 里的
`hmusic-<版本>-SHA256SUMS.txt` 自行确认。

放行方式（任选其一）：

1. 打开一次被拦下的 `HMusic.app`，然后到 **系统设置 → 隐私与安全性**，在底部的提示里点 **“仍要打开”**，
   再确认一次即可。之后每次启动都不会再拦。
2. 命令行直接去掉下载隔离标记：

   ```bash
   xattr -dr com.apple.quarantine "/Applications/HMusic.app"
   ```

macOS 15（Sequoia）起，旧办法“在 Finder 里右键选择打开”已经不能再绕过 Gatekeeper，必须走上面的
系统设置或命令行方式。

另外，ad-hoc 签名没有稳定的签名身份，而 macOS 钥匙串条目的访问权限是绑签名身份的：升级到新版本后
可能需要重新登录一次 Server。这不是故障，等有 Developer ID 正式签名后会消失。

### Windows

优先下载 `hmusic-<版本>-windows-x64-setup.exe`，运行后按中文安装向导完成安装。安装器默认只为当前用户
安装到 `%LocalAppData%\Programs\HMusic`，会创建开始菜单入口，并可在向导中选择创建桌面快捷方式；以后可
从 Windows“应用和功能”或安装目录中的卸载程序移除。

安装包未做 Authenticode 签名，因此会遇到两道拦截：浏览器（尤其 Edge）下载时可能提示“已阻止不安全下载”，
需要在下载列表里选择保留；运行时 SmartScreen 会弹出“Windows 已保护你的电脑”，点 **“更多信息 → 仍要运行”**
即可。SmartScreen 依据文件声誉判断，未签名的包每发一个新版本都要重新积累声誉，所以这个提示短期内不会消失。
少数国产安全软件也可能对未签名的安装器误报，必要时把安装目录加入信任。建议安装前用 Release 里的
`hmusic-<版本>-SHA256SUMS.txt` 核对下载完整性（`certutil -hashfile <文件> SHA256`，再和文件里对应的
那一行比一比）。

受限环境也可以下载 `hmusic-<版本>-windows-x64.zip`，完整解压后运行 `HMusic/hmusic.exe`，不要只把 exe
单独复制出来。

### Linux

下载 `hmusic-<版本>-linux-x64.tar.gz`，解压后运行：

```bash
./HMusic/hmusic
```

包内包含 `HMusic/hmusic.png` 和 `HMusic/hmusic.desktop`，运行时窗口会使用 HMusic 图标；当前仍是便携包，
不会自动注册系统菜单。系统需要 GTK 3 和 libsecret 运行库。当前 Linux 包面向 x86_64 桌面环境，未提供
ARM64 构建。

Windows/Linux 当前可用于连接 Server、管理内容和遥控服务端/音箱；本机音频、Windows SMTC 与 Linux
MPRIS 尚未完成。macOS 已支持本机播放和系统媒体控制，但三端托盘、关窗驻留和自动更新仍在后续范围。

## 常见问题

### 找不到 Server

- 确认手机和 Server 连接同一个局域网。
- 从手机浏览器访问 `http://<server-ip>:6650/api/v1/system/info`。
- 检查服务器防火墙是否放行 TCP `6650`。
- Docker 部署确认使用 host network；Docker Desktop 的 macOS/Windows 环境优先切换 native 模式。

### 公网访问失败

公网域名必须配置有效 HTTPS 证书，并在 Server 设置 `HMUSIC_PUBLIC_BASE_URL`。不要为了绕过证书错误而
关闭客户端校验。仅在可信局域网使用 HTTP。

### iOS 无法连接

首次使用需要允许本地网络权限。若之前拒绝过，请在系统设置中为 HMusic 重新打开“本地网络”。

### 能搜索但没有声音

先在 Server 管理页播放内置测试音频，再检查默认播放设备和音源插件。客户端本机播放与小爱音箱播放是两条
链路，分别验证可以缩小问题范围。

### 后台播放中断

确认使用的是正式 Release 构建，并在系统设置中允许通知和后台活动。退出账号或收到 `401` 后需要重新登录，
这是服务端会话失效时的预期行为。

## 数据与升级

Server 的 `.env` 和 `data/` 是持久化数据，升级前应备份。App 本身不托管用户曲库，也不会替用户保存音乐
源账号；账号、播放历史和媒体数据由用户自己的 Server 管理。
