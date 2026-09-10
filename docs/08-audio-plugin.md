# 08 - Flutter 后台音频架构

> 实现组合：`audio_service` + `just_audio` + `audio_session`。本文定义业务状态机，插件安装细节
> 以锁入 `pubspec.lock` 的版本文档为准。

## 1. 目标与边界

必须支持 Android/iOS 前台、后台、锁屏本机播放，以及系统播放/暂停/上下曲/seek。
Server 模式的小米音箱由 Server 执行，直连模式由 `DirectPlaybackRepository` 经 MiNA/ubus
控制；两者都不启动本机音频。直连音箱的自动连播依赖 App 前台调度，不能承诺 iOS 挂起后持续
切歌，也不使用静音音频保活。实现及验收记录见 [14](14-direct-mode-migration-plan.md)。

服务端的 `local-browser` 名称是历史兼容标识；Flutter 本机播放继续使用该 deviceId，不能擅自改名。

## 2. 状态所有权

| 数据 | 权威来源 |
|---|---|
| track、queueIndex、queueLength、playMode、目标 device | 活动模式的 PlaybackState/Queue（Server 或直连本地仓库） |
| position、bufferedPosition、duration、processingState | just_audio Player |
| 锁屏元数据、系统按钮可用性 | AudioHandler 根据两侧状态投影 |

不得用仓库每 3 秒回写值反向校准正在播放的本机 position，否则进度会回跳。

## 3. 组件

```text
PlayerViewModel / 系统媒体按钮
  -> HMusicAudioHandler（串行命令、状态归并、report/ended/recovery）
      -> AudioPlayer / AudioSession
      -> RoutedPlaybackRepository（稳定实例，按模式路由）
          -> ApiPlaybackRepository（Server）
          -> DirectPlaybackRepository（本地队列、解析、MiNA/ubus）
```

`HMusicAudioHandler` 必须在没有 Flutter 页面运行时独立完成：定时回写、ended 推进、加载下一曲、
媒体按钮和中断处理。Widget 生命周期里的 Timer 不能承担后台正确性。

模式切换通过同一个 Handler 的 `transitionBackend` 停止旧目标、清理已装载音频与媒体快照，
再提交新模式。命令、组合播放操作和异步 UI 结果均核对 generation；本机 epoch 拒绝迟到的 ended。

## 4. URL 与鉴权

Server 模式的 `/playback/play` 返回签名 `streamUrl`，音频代理不要求 JWT，适合原生播放器直接拉取和 Range seek。
但 URL host 来自 Server 的 `HMUSIC_PUBLIC_BASE_URL`，可能是 `127.0.0.1`。

```dart
Uri rebaseStreamUrl(Uri serverBase, String streamUrl) {
  final source = Uri.parse(streamUrl);
  return serverBase.replace(path: source.path, query: source.query);
}
```

生产实现还要拒绝非 http/https、缺失 `/api/v1/proxy/` 前缀或解析失败的值。不要记录完整签名 URL。

后台 handler 调用 `/playback/local-report` 等 JSON API 仍需 Bearer token；token 从安全会话仓库读取。

直连使用 `ModeStreamUrlRebaser` 保留已校验的上游或临时代理 URL，不重绑定到 Server。
本机 HTTP 音频经 loopback 代理兼容 AVFoundation ATS；音箱需代理时使用 LAN IPv4。
代理只接受当前进程生成的随机令牌映射，流式保留 Range/206、长度和编码响应头，模式退出时关闭。
它不携带 Server Bearer/小米会话，也不提供用户公共代理配置。

## 5. 命令时序

以下 HTTP 路径描述 Server 模式；直连执行同名仓库方法，复用同一套 Handler 装载、上报、
恢复和系统媒体控制时序，禁止在 ViewModel 另建播放器。

### 点播

1. 串行锁获取命令权。
2. `POST /playback/play {track, deviceId:"local-browser", positionMs?}`。
3. 校验返回 state/track/streamUrl，重绑定 URL。
4. 设置 MediaItem，`setAudioSource`，按 positionMs seek。
5. state 为 playing 时播放，发布 AudioService 状态。

队列页点播一步发送 `{track, queueIndex}`（Server 已修复 S-P0-01 并有重复歌曲回归测试）。
仅当对接未修复的旧 Server（play 对 queueIndex 返回 400）时，降级为先 `/queue/current{index}`
再发不带 queueIndex 的 play；两种模式不可混用，完整兼容矩阵见 12。

### 播放/暂停

- 本机按钮先即时操作 AudioPlayer，再调用 Server resume/pause；失败时回滚或刷新 Server state。
- 远程设备只调用 Server。
- 锁屏按钮进入相同 coordinator/handler 路径，不另写 API 时序。
- 冷启动先发布保存曲目和位置，播放器装载前不使用其零进度覆盖快照；显式播放才重新解析。
  解析阶段即发布 loading，失败后恢复可重试状态。歌词、播放器和系统媒体面板使用一致的恢复位置。
- 模式切换以暂停保留旧位置，停止本机后再接入目标仓库；状态订阅等待该串行事务结束。
  两模式的队列与偏好独立，返回时不自动播放。退出账号仍先 stop 再清会话。

### Seek 与音量

- seek 先操作 player，再提交 `/playback/seek`；拖动中节流，松手必交最终值。
- 本机音量是 player 真值，同时回写 `/playback/volume`；系统硬件音量不映射为 0-100 应用音量。

### 播放结束

1. Player 到 completed，防重入标记当前 track key。
2. `POST /playback/local-report {ended:true}`。
3. 若返回下一曲 playing + streamUrl，立即加载并播放。
4. 队列尽头正常收尾（stopped）；下一曲装载失败走 §7 恢复链，恢复失败按 §7
   如实收场，禁止停留在「正在播放」假象。同一 completed 事件最多上报一次。

## 6. 周期回写

播放或暂停且当前为本机设备时，每 3 秒：

```json
{
  "state": "playing",
  "positionMs": 42000,
  "durationMs": 231000
}
```

- 单飞：上一请求未结束不发下一次。
- position 取 player，duration 未知则省略。
- 暂停后立即回写一次；停止时停止 timer。
- 网络失败不停止音频，指数退避到最多 15 秒；恢复后立即补一帧。
- 401 停止音频并向 UI 发布会话失效。
- `ended:true` 属于非幂等推进命令，只发一次；超时后刷新 state/queue 归并，禁止自动重试跳过两首。

## 7. 直链失效恢复

Player 网络错误且仍有当前 track 时：

1. 记录 position。
2. 调 `/playback/play {track, deviceId:"local-browser", positionMs}` 重新解析。
3. 重绑定新 URL、seek、恢复播放。
4. 同一 track 60 秒内最多自动恢复一次，防止坏源循环。
5. 装载黑洞防护：`setAudioSource` 20 秒未决视同加载失败，走同一恢复链
   （坏直链可能既不成功也不报错，不限时会无声卡死在 loading）。
6. 恢复失败的如实收场：暂停本机 player（清掉上一首残留的 playing 真值，
   否则周期回写继续谎报）、`local-report {state:"paused"}` 回写服务端（进度
   保留在目标点，稍后重试可续），全局通知流弹「音源加载失败」toast，并向
   前台冒泡 `PlaybackLoadException`；语义状态不得停留在 playing。
7. resume 响应无 streamUrl 且本机无已装载音频时（队列播完直链被清、冷启动
   接续旧会话），原曲重解析装载，不做只翻状态不出声的 bare play()。

Server 已实现暂停超 20 分钟的 resume 重解析；客户端恢复仍需保留，因为播放中途也可能失效。
Server 音频代理对上游握手限时 15 秒（仅响应头阶段，正文流不限时），黑洞直链
快速转 502 让客户端立刻进入恢复链，而不是无限等待。

直连 LX 返回地址后，以相同音频请求头发起 `Range: bytes=0-0` 的有限探测。
只有 200/206、正文非空且非 HTML/JSON 错误页才作为可播放候选；403、空正文和超时
沿既有顺序回退音质、插件和匹配平台，不修改用户音质偏好。单次探测最多 5 秒，计入
解析总计 45 秒预算。仅记录状态码和错误类别，不记录签名地址或插件密钥。

## 8. 队列与播放模式

- Server 模式不在客户端复制队列推进算法；直连模式由 `DirectQueueRepository` 和
  `DirectPlaybackRepository` 持有权威本地队列，与 Server 数据分开存储。
- list_loop/single_loop/shuffle/sequence/single_once 由活动仓库的 ended 结果决定。
- AudioService 展示活动 Queue 快照，next/previous 调活动仓库后再装载返回 state。
- `/playback/events` 当前不是持续流；前台状态对齐使用轮询，后台依赖命令返回值和 report。
- 直连音箱返回前台时保留离开前的曲末 deadline，并核对设备状态、audioId 和安全存储中的
  userId；无法确认是本 App 当前账号发起的播放时，不擅自推进。生命周期变化后的旧响应丢弃。

## 9. 音频焦点与中断

会话必须在建 `AudioPlayer` 之前配置（`hmusicAudioHandlerProvider` 内
`AudioSession.instance.configure(AudioSessionConfiguration.music())`，2026-08-01 补）。
装了 `audio_session` 却不 configure 时平台按「未声明用途」的默认会话走：iOS 静音键
掐播放、中断后不恢复；macOS 上曲目与输出设备采样率不一致（44.1k 曲目 / 48k 扬声器）
时重采样劣化，表现为持续电流刺啦声。music() 预设声明本 App 为音乐播放器。

| 场景 | 预期 |
|---|---|
| 来电/闹钟 | 暂停或 duck 由 audio_session 决策；中断结束只在系统允许且此前正在播时恢复 |
| 拔耳机/蓝牙断开 | 立即暂停，禁止扬声器突放 |
| 短暂焦点丢失 | duck 或暂停，状态同步到通知 |
| App UI 被销毁 | 后台音频、report、ended 继续 |
| 用户从任务管理器明确停止 | 不擅自复活播放 |
| Server 离线 | 当前缓冲可继续；命令提示离线，ended 不本地猜下一曲 |

## 10. MediaItem 映射

- id：`track.id`
- title：`track.title`
- artist：`track.artist`
- album：`track.album`
- artUri：合法的 `coverUrl`
- duration：Server durationMs 或 player 探测值
- extras：source/sourceTrackId/queueIndex，禁止放 token 或签名 URL

## 11. 验收矩阵

- [ ] 前台 play/pause/seek/volume/next/previous
- [ ] 锁屏后继续 30 分钟且进度连续
- [ ] 后台播完自动下一曲，单曲循环和队列尽头正确
- [ ] 锁屏封面元数据和按钮状态正确
- [ ] 返回 URL host 为 127.0.0.1 时仍能通过 LAN server base 播放
- [ ] 来电、闹钟、拔耳机、蓝牙切换符合预期
- [ ] 网络断开重连、音源 403 自动恢复最多一次
- [ ] 401 停止播放并回登录页
- [ ] Android 进程回收与 iOS UI 挂起边界有真机记录
