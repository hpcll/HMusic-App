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

下载 `hmusic-<版本>-macos-universal-adhoc.zip`，解压后将 `HMusic.app` 移入“应用程序”。该包同时支持
Apple Silicon 与 Intel，使用 ad-hoc 签名但没有 Developer ID 公证。首次打开优先在 Finder 中右键选择
“打开”；若系统仍因下载隔离阻止启动，可执行：

```bash
xattr -dr com.apple.quarantine "/Applications/HMusic.app"
```

### Windows

下载 `hmusic-<版本>-windows-x64.zip`，完整解压后运行 `HMusic/hmusic.exe`，不要只把 exe 单独复制出来。
该包未做 Authenticode 签名，SmartScreen 可能需要用户确认“更多信息 > 仍要运行”。

### Linux

下载 `hmusic-<版本>-linux-x64.tar.gz`，解压后运行：

```bash
./HMusic/hmusic
```

系统需要 GTK 3 和 libsecret 运行库。当前 Linux 包面向 x86_64 桌面环境，未提供 ARM64 构建。

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
