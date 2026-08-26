# App 安装与故障排查

## 连接流程

1. 部署并启动 [HMusic-Server](https://github.com/hpcll/HMusic-Server)。
2. 在浏览器打开 Server 的 `/app/`，创建管理员账号并完成初始化。
3. 安装 HMusic App，在连接页填写 Server 基础地址，不要填写 `/app/` 路径。
4. 登录后执行一次搜索和播放，确认服务端与本机播放链路都正常。

Server 默认端口为 `6650`。例如 Server 地址是 `http://192.168.1.20:6650`，App 中也填写这个地址。

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
