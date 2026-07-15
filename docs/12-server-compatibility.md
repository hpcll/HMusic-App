# 12 - HMusic-Server 客户端兼容矩阵

> 基线：2026-07-12，HMusic-Server main + 当前工作树（queueIndex、真探测、切设备同步播放目标、
> 下载缓存、运行配置策略生效 均已实现并通过测试）。
> 目标：允许 Flutter 先实现稳定客户端；Server 契约债务后续修复时不破坏现有版本兼容。

## 1. 已验证结论

通过路由/Zod/Web 调用静态核对和 Fastify inject 验证：

- `/playback/play.queueIndex` strict schema 冲突已修复。
- Web 队列精确点播已改为一步调用 `/playback/play {track, queueIndex}`，避免指针已变更但播放失败的半成功窗口。
- Server 集成测试已覆盖重复歌曲队列 index 0/1，显式发送 `queueIndex` 返回 200 且 playback.queueIndex 正确。
- `/config` 的 `searchStrategy`/`resolveStrategy`/`defaultQuality` 现在真正生效（此前为死配置）：
  搜索按策略排平台领先序、解析按策略跨源换源、点播/下载用默认音质首选档。
- `/config` 的 `lxPlugins` 条目补齐 `sourceUrl`，GET 读出的配置可原样 PATCH 回去（strict 不再拒收）。

## 2. 兼容规则

| ID | Server 现状 | 客户端 P0 规则 | Server 后续修复 |
|---|---|---|---|
| C-01 | `/playback/play` schema 接受可选非负整数 `queueIndex` | 队列点播直接 `/playback/play {track, queueIndex}` | 保持 additive 兼容；旧客户端不传仍可播放 |
| C-02 | `/playback/events` 发一帧即关闭 | 不建立 SSE；前台轮询和命令返回值同步 | 实现持续 SSE、心跳、断线与事件序列后再启用 |
| C-03 | `streamUrl` host 取 Server publicBaseUrl，可能不可达 | 保留 path/query，scheme/host/port 重绑定到当前 server base | Server 可提供相对 proxyUrl 或客户端可达 base |
| C-04 | `/system/info.capabilities` 未列出 playlists/charts/stats/downloads 等现有能力 | 只用 name/apiVersion 探活；capabilities 仅作 hint，不隐藏功能 | 补齐且版本化 capability schema |
| C-05 | 全新 Server PlaybackState `volume=0` | 本机音量用客户端偏好，首次默认 100%；远程音箱使用 Server volume | Server 明确本机/设备音量语义或采用非零默认值 |
| C-06 | 无效 JWT 请求 `/auth/status` 返回 200 + authenticated=false，不返回 401 | 有本地 token 但 authenticated=false 时清 token 并进入登录页 | 保持兼容即可，文档明确语义 |
| C-07 | 重启恢复 paused，`streamUrl` 被清空 | resume 后必须消费新返回 state/streamUrl，不能复用旧 URL | 保持现状 |
| C-08 | `local-browser` 是全局虚拟设备 | P0 只允许单个活跃本机客户端；不做多端状态合并 | 后续增加 client/session identity |
| C-09 | `/devices/:id/select` 当前工作树新增 `playback` 字段 | JSON 解码忽略未知字段；解析 selectedDeviceId 和可选 playback | 冻结新返回 DTO 并补测试 |
| C-10 | Server DTO 可能添加字段 | 所有响应模型容忍未知字段；只对 P0 必需字段做强校验 | 契约采用向后兼容的 additive changes |

## 3. 非幂等请求与重试

以下请求不得由 Dio 拦截器自动重试：

- `/auth/setup`、`/auth/login`、`/auth/password`
- `/playback/play|next|previous|local-report(ended:true)`
- 队列/歌单/下载的 POST、PUT、PATCH、DELETE
- 小米登录、验证码、设备控制和 TTS

原因：请求可能已在 Server 成功，但客户端在响应返回前超时。盲目重试会重复记录播放历史、跳过歌曲、
重复添加项目或重复发设备命令。

客户端策略：

- 自动重试只允许幂等 GET，最多一次，且仅限明确的瞬时网络错误。
- 播放命令超时后 GET `/playback/state` 归并，不自动再次发送命令。
- `ended:true` 只发送一次；响应不确定时刷新 playback/queue，若 Server 已推进则装载新曲，未推进则
  停止并等待用户操作，绝不盲重试导致跳两首。
- 周期性 local-report（不含 ended）是状态覆盖，可在 single-flight 和退避下重新上报最新状态。

## 4. 本机音量兼容

Server 的 volume 同时承载音箱音量和本机状态，初始值为 0。Flutter 采用：

- `LocalVolumeStore` 保存当前设备上的本机音量，首次默认 1.0。
- 本机播放以 just_audio/LocalVolumeStore 为真相源，不把全新 Server 的 0 自动应用为静音。
- 用户拖动本机音量时立即更新播放器和本地偏好，并尽力回写 Server 0-100 供 UI 状态展示。
- 远程音箱选择时改用 Server volume，不把手机本机偏好推给音箱。
- 切换设备时 ViewModel 明确切换音量来源，禁止共用一个未经标记的 slider state。

## 5. 地址与模型解码

- ServerAddressPolicy 接受 http/https、域名、IPv4、方括号 IPv6；去尾斜杠，拒绝 credentials/query/fragment。
- App Store 版仅私有/本地地址允许 HTTP，公网必须 HTTPS。
- Track.raw 用 `Object?` 原样保留，发回 Server 时不得裁剪；空字符串 URL/coverUrl 应转换为 null/省略。
- durationMs、positionMs、updatedAt 使用 Dart int；未知枚举值进入 fallback，不导致整个页面崩溃。
- Error 按 `{error:{code,message,details}}` 解码；非 JSON/空响应生成通用 ApiFailure。

## 6. Server 后续待办

- [x] playSchema 增加 `queueIndex` 并覆盖两条重复曲目集成测试
- [ ] 决定是否保留/实现真实 `/playback/events`，否则移除误导端点
- [ ] 补齐并版本化 `/system/info.capabilities`
- [ ] 明确本机音量与远程设备音量的契约
- [ ] 为 non-idempotent playback/ended 设计 commandId/idempotency key
- [ ] 冻结 devices select 的新增 playback 返回模型
- [ ] 修复 Fastify 6 `maxParamLength -> routerOptions` 弃用警告
