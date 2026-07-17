# 08 - Flutter 后台音频架构

> 实现组合：`audio_service` + `just_audio` + `audio_session`。本文定义业务状态机，插件安装细节
> 以锁入 `pubspec.lock` 的版本文档为准。

## 1. 目标与边界

必须支持 Android/iOS 前台、后台、锁屏本机播放，以及系统播放/暂停/上下曲/seek。
远程小米音箱播放仍由 Server 执行，Flutter 只遥控并展示状态，不启动本机音频。

服务端的 `local-browser` 名称是历史兼容标识；Flutter 本机播放继续使用该 deviceId，不能擅自改名。

## 2. 状态所有权

| 数据 | 权威来源 |
|---|---|
| track、queueIndex、queueLength、playMode、目标 device | Server PlaybackState/Queue |
| position、bufferedPosition、duration、processingState | just_audio Player |
| 锁屏元数据、系统按钮可用性 | AudioHandler 根据两侧状态投影 |

不得用 Server 每 3 秒回写值反向校准正在播放的本机 position，否则进度会回跳。

## 3. 组件

```text
PlaybackController (UI intent)
  -> PlaybackCoordinator (串行命令、Server 状态归并)
      -> HMusicApi
      -> HMusicAudioHandler (后台可存活)
          -> AudioPlayer
          -> AudioSession
          -> HMusicApi (report/ended/recovery)
```

`HMusicAudioHandler` 必须在没有 Flutter 页面运行时独立完成：定时回写、ended 推进、加载下一曲、
媒体按钮和中断处理。Widget 生命周期里的 Timer 不能承担后台正确性。

## 4. URL 与鉴权

`/playback/play` 返回签名 `streamUrl`，音频代理不要求 JWT，适合原生播放器直接拉取和 Range seek。
但 URL host 来自 Server 的 `HMUSIC_PUBLIC_BASE_URL`，可能是 `127.0.0.1`。

```dart
Uri rebaseStreamUrl(Uri serverBase, String streamUrl) {
  final source = Uri.parse(streamUrl);
  return serverBase.replace(path: source.path, query: source.query);
}
```

生产实现还要拒绝非 http/https、缺失 `/api/v1/proxy/` 前缀或解析失败的值。不要记录完整签名 URL。

后台 handler 调用 `/playback/local-report` 等 JSON API 仍需 Bearer token；token 从安全会话仓库读取。

## 5. 命令时序

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

## 8. 队列与播放模式

- 本地不复制权威队列推进算法。
- list_loop/single_loop/shuffle/sequence/single_once 全由 Server 的 ended 结果决定。
- AudioService 可展示当前 Server Queue 快照，但 next/previous 必须调 Server 后再装载返回 state。
- `/playback/events` 当前不是持续流；前台状态对齐使用轮询，后台依赖命令返回值和 report。

## 9. 音频焦点与中断

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
