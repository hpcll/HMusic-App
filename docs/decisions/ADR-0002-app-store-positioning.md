# ADR-0002 - App Store 产品定位：自托管个人音乐库客户端

- 状态：Accepted / Frozen
- 日期：2026-07-11
- 决策者：项目所有者

## 一句话定位

**HMusic 是连接用户 NAS 或家庭服务器上 HMusic-Server 的个人音乐库播放器，支持家庭音箱遥控和移动端后台播放。**

英文定位：

**HMusic is a companion player for your self-hosted music library, powered by HMusic Server on your NAS or home server.**

## 产品事实

- HMusic App 本身不提供公共音乐目录、订阅服务、广告或开发者运营的云曲库。
- 用户在自己的 NAS/家庭服务器上运行 HMusic-Server，App 通过局域网或用户配置的 HTTPS 地址连接。
- App 播放用户有权访问的个人音乐文件和 Server 返回的合法内容。
- App 可以管理播放队列、歌单、歌词、统计，并控制兼容的家庭音箱。
- 移动端支持锁屏和后台播放；远程音箱模式只做遥控，不用静音音频保活。
- App 不在设备端执行 Server 下发的 JavaScript、LX 插件或其他代码。

## NAS 表述边界

不要说“App 直接读取 NAS 文件”或“App 内置 NAS 协议”，因为当前架构是：

```text
NAS / 家庭服务器运行 HMusic-Server
              ↑
        HMusic App 通过 HTTP/HTTPS 连接
```

商店准确表述应是“播放运行在 NAS/家庭服务器上的 HMusic Server 音乐库”。未来若增加 SMB/WebDAV
等 App 直连能力，必须另做架构和权限评估。

## 推荐 App Store 文案

### App 名称

`HMusic`

### 副标题

中文：`播放你的家庭音乐库`

英文：`Your self-hosted music player`

### 简介

中文：

> HMusic 是 HMusic Server 的配套播放器。将 HMusic Server 运行在你的 NAS 或家庭服务器上，
> 连接后即可浏览和播放自己的音乐库，管理队列与歌单、查看歌词和统计，并控制兼容的家庭音箱。
> HMusic 不提供公共曲库、订阅或广告，音乐内容由你自己的服务器提供。

英文：

> HMusic is the companion player for HMusic Server. Run HMusic Server on your NAS or home server,
> connect the app over your local network or a secure remote connection, and play your own library
> with playlists, queue control, lyrics, listening stats, background playback, and compatible speaker control.
> HMusic does not provide a public catalog, subscriptions, or advertising.

### 功能描述

- Connect to a self-hosted HMusic Server
- Play your personal music library
- Manage queues and playlists
- View synchronized lyrics and listening statistics
- Continue playback in the background and on the lock screen
- Control compatible home speakers
- Use local network HTTP or secure HTTPS connections according to your server setup

不要在商店元数据中使用：`破解`、`免费音乐`、`解析直链`、`绕过限制`、`下载付费音乐`、
`聚合全网音源`、`QQ/网易云/酷我曲库` 等表述。

## App Review Notes 模板

```text
HMusic is a companion app for a self-hosted HMusic Server.
The reviewer does not need a NAS or home network for testing.

Demo Server: https://review.example.com
Username: [review account]
Password: [review password]

Test steps:
1. Open HMusic and enter the Demo Server URL.
2. Sign in with the credentials above.
3. Open Search and play the sample track.
4. Test pause, seek, queue, lyrics, and background playback.
5. Open Settings to view the compatible speaker controls.

The Demo Server contains only public-domain or otherwise authorized test audio.
The app does not include a public music catalog, subscriptions, advertising, or executable plugin code.
Local Network permission is used to connect to a user's own HMusic Server on their home network.
Background Audio is used only while the user is playing audio on the device.
```

审核环境不能使用真实小米账号、家庭设备、私人播放历史或未授权音乐。

## 功能发行边界

| 功能 | App Store 版 | Server Web/桌面直发版 |
|---|---|---|
| 自托管 Server 连接 | 保留 | 保留 |
| 本机播放、后台、锁屏 | 保留 | 保留 |
| 队列、歌单、歌词、统计 | 保留 | 保留 |
| 兼容音箱遥控 | 保留 | 保留 |
| LX JavaScript 编辑/导入 | 暂不放入商店版 | 可保留，需权利和安全评估 |
| 服务端下载管理 | 暂不放入商店版 | 可保留，需权利和安全评估 |
| 第三方平台名称/解析宣传 | 不出现在元数据 | 不作为产品宣传 |

上述差异必须是明确的 `StoreEdition` 编译配置，不根据审核账号、地区或远程开关临时伪装。

## 复核条件

若未来加入公共曲库、订阅、第三方登录、云端账号、付费功能、SMB 直连或第三方平台授权，
必须重新审查本 ADR、隐私政策、App Store 元数据和审核路径。
