# 08 · tauri-plugin-hmusic-audio 插件规格（移动本机播放）

> 读者：实现移动音频插件的人（Swift/Kotlin/Rust + JS 桥）。本文精确到命令、事件、
> 错误码、边角行为矩阵——照着写即可，无需再做设计决策。
> 前置阅读：docs/01 决策 E（音频后端抽象）、docs/06 M4。

## 0. 一个决定形态的事实：后台时 webview JS 会被挂起

进后台/锁屏后，原生播放器继续出声，但 **webview 里的 JS 定时器与事件循环被系统暂停**。
而"播完→上报→队列推进→放下一首"、"锁屏点暂停/下一曲"原本都靠 JS 驱动。

**结论：插件必须是"迷你客户端"**——持有 `serverBase + token`，在 JS 不可用时自己直连
服务端完成状态上报与队列推进。由此推出全文最重要的职责划分：

| 动作发起方 | 谁与服务端通信 | JS 的角色 |
|---|---|---|
| **UI 按钮**（前台，JS 活着） | JS（现有流程不变：JS→API→refreshPlayback→backend 命令） | 主导 |
| **原生侧发起**（锁屏键/耳机键/来电中断/播完 ended） | **插件直连服务端**，随后广播 `audio:state` | 若活着，收事件同步 store；睡着则忽略 |

> 这条划分消灭了两类必然 bug：双重推进队列（JS 和原生都上报 ended）与
> 前后台状态打架（来电暂停后回前台被 syncLocalAudio 误恢复）。

## 1. JS 音频后端接口（决策 E 的精确落地）

`HMusic-Server/web/main.js` 重构：对 `<audio>` 的直接操作收口为 `audioBackend`，
编排逻辑（syncLocalAudio / startLocalReporting / handleEnded）不动。现有代码逐条去处：

| main.js 现有代码 | 归属 | 后端接口 |
|---|---|---|
| 换源分支：`src=`/`currentTime=`/`play()` | backend | `load(opts)` |
| 状态对齐分支 `play()/pause()` | backend | `play()` / `pause()` |
| `stopLocalAudio()` 的元素清理 | backend | `stop()`（清 reporting 定时器留编排层） |
| `localAudio.volume = v/100` | backend | `setVolume(v01)` |
| `localSeek/localPlay/localPause` | backend | `seek(ms)` / `play()` / `pause()` |
| `localPositionMs/localDurationMs` | backend | `positionMs()` / `durationMs()`（**同步返回**） |
| `localAudio.paused` 判断 | backend | `playing()` |
| `primeLocalAudio()` | backend | `prime()`（原生后端 = no-op） |
| `'ended'` 监听 → POST local-report | 编排层 `handleEnded(payload?)` | `onEnded(cb)` |
| `'error'` 监听 → toast | 编排层 | `onError(cb)` |
| `toSameOriginUrl()` | 编排层（客户端改用 serverBase 拼绝对地址，决策 B） | — |

```ts
interface AudioBackend {
  load(opts: {
    url: string;                // 已拼好的绝对 streamUrl
    positionMs?: number;        // 恢复进度（暂停态重载）
    autoplay: boolean;          // 仅服务端 state==="playing" 时 true
    meta: { title: string; artist: string; album?: string;
            coverUrl?: string; durationMs?: number };   // 锁屏元数据
  }): void;
  play(): void; pause(): void; stop(): void;
  seek(positionMs: number): void;
  setVolume(v01: number): void;
  positionMs(): number; durationMs(): number; playing(): boolean;  // 同步
  prime(): void;
  onEnded(cb: (payload?: { state?: HMusicPlaybackState }) => void): void;
  onError(cb: (message: string) => void): void;
}
```

**handleEnded 的双态契约**（防双重推进的关键）：

```js
async function handleEnded(payload) {
  if (payload?.state) {          // 原生后端：插件已直连服务端推进完毕，附回新状态
    store.playback = payload.state;
    syncLocalAudio();            // 新 streamUrl 已在播（原生侧），此处仅对齐 UI
    return;
  }
  // HTMLAudio 后端（浏览器/桌面）：维持现状——JS 自己上报并推进
  store.playback = await api("/playback/local-report", { method:"POST", body:{ ended:true } });
  syncLocalAudio();
}
```

**同步取值的实现约束**：原生侧 `position` 是异步 invoke，而引擎要求 `positionMs()` 同步。
NativeAudioBackend 内部维护缓存：每 1s invoke `position` 刷新 `{positionMs, durationMs,
playing, at}`，`positionMs()` 返回 `缓存值 + (playing ? now-at : 0)` 插值。前台 3s
local-report 照旧由编排层驱动；后台 JS 挂起自然停报（服务端进度短暂陈旧，可接受）。

## 2. 插件命令面（JS → 原生，`invoke("plugin:hmusic-audio|<cmd>")`）

| 命令 | 参数 | 返回 | 说明 |
|---|---|---|---|
| `configure` | `{serverBase, token}` | — | **启动与 token 变化时必调**；给后台直连用。退出登录调 `teardown` |
| `load` | 同 AudioBackend.load 展平 | — | 换源 + 喂锁屏元数据；重复 url 幂等 |
| `play` / `pause` / `stop` | — | — | stop 额外清锁屏/通知 |
| `seek` | `{positionMs}` | — | 未就绪时暂存为 pendingSeek，ready 后执行 |
| `setVolume` | `{volume: 0..1}` | — | 设播放器音量（硬件音量独立叠加，移动端主用硬件键） |
| `position` | — | `{positionMs, durationMs, playing, buffering}` | JS 1s 轮询 |
| `teardown` | — | — | 停播、清会话/通知、忘记 configure |

错误码（invoke reject）：`E_NOT_CONFIGURED` / `E_LOAD_FAILED` / `E_NO_ITEM`（未 load 就 play 等）。

## 3. 事件面（原生 → JS，`listen()`）

| 事件 | 载荷 | 触发 |
|---|---|---|
| `audio:state` | `{state: HMusicPlaybackState}` | **一切原生自主动作后**（锁屏键/耳机/中断/ended 自续播），载荷 = 服务端返回的最新状态。前台 JS 收到即 `store.playback = state` + syncLocalAudio 对齐；JS 睡着则错过——回前台的 refreshPlayback 自然补齐 |
| `audio:ended` | `{state?}` | 播完。**原生已自行完成上报+推进**，state 为推进后状态 → 走 handleEnded 双态契约 |
| `audio:error` | `{message}` | 加载/解码失败（不触发 ended） |

> 桌面的 `media:play|pause|next|previous` 事件仍存在（媒体键→JS→API）；**移动端不用它**——
> 锁屏控制由插件直连服务端处理（JS 可能睡着，绕 JS 的往返不可靠）。

## 4. 原生自主动作的统一流程（插件内实现）

```
锁屏/耳机 播放|暂停  → 本地 play/pause → POST /playback/local-report {state, positionMs}
播完 ended           → POST /playback/local-report {ended:true}
锁屏 下一曲|上一曲    → POST /playback/next | /playback/previous
        ↓ 三者的响应都是最新 HMusicPlaybackState
若 state.streamUrl 变化 → 改写为 serverBase+path 后 load + （state==="playing"?play）
更新锁屏元数据（state.track）
emit audio:state {state}（audio:ended 场景改发 audio:ended {state}）
队列尽头（idle/stopped）→ stop + 清通知
```

HTTP 细节：`Authorization: Bearer <token>`；超时 10s；失败重试 1 次；再失败→本地暂停 +
emit `audio:error`（宁停不乱，回前台由 refreshPlayback 收敛）。

## 5. 中断 / 焦点 / 拔耳机 行为矩阵

| 场景 | iOS 信号 | Android 信号 | 行为 |
|---|---|---|---|
| 来电/Siri/他 App 独占 | interruption `.began` | `AUDIOFOCUS_LOSS_TRANSIENT` | 本地暂停 + 上报 paused + emit |
| 上述结束且可恢复 | `.ended` + `.shouldResume` | `AUDIOFOCUS_GAIN`（此前在播） | 本地恢复 + 上报 playing + emit |
| 他 App 长期占用 | — | `AUDIOFOCUS_LOSS` | 同来电暂停，**不**自动恢复 |
| 短暂提示音（导航等） | 系统自动 duck | `LOSS_TRANSIENT_CAN_DUCK` | Android 手动降音量至 0.2，恢复后回原值；不改播放态不上报 |
| 拔耳机/断蓝牙 | route change `.oldDeviceUnavailable` | `ACTION_AUDIO_BECOMING_NOISY` | 本地暂停 + 上报 + emit（行业惯例：外放前先停） |

## 6. iOS 实现要点（Swift）

- `AVPlayer` 流播；`AVAudioSession` category `.playback`，`setActive(true)` 于首次 play。
- Xcode：Background Modes → **Audio, AirPlay, and Picture in Picture** 勾选。
- **ATS**：Info.plist `NSAppTransportSecurity → NSAllowsArbitraryLoads=true`
  （家庭服务器是 http；不放行则 AVPlayer **无声且无报错**）。
- 锁屏：`MPNowPlayingInfoCenter`（title/artist/album/duration/elapsed/rate）；封面异步
  `URLSession` 拉 coverUrl → `MPMediaItemArtwork`（失败则跳过，勿阻塞元数据主体）。
- 控制：`MPRemoteCommandCenter` play/pause/toggle/next/previous/changePlaybackPosition
  （seek 条）→ 走 §4 统一流程。
- ended：`AVPlayerItemDidPlayToEndTime` 通知；error：KVO `status == .failed`。
- pendingSeek：item 未 ready 时暂存，`.readyToPlay` 后执行。

## 7. Android 实现要点（Kotlin）

- media3 **ExoPlayer** + **MediaSessionService**（媒体三件套标准形态）：前台服务 +
  MediaStyle 通知（即锁屏控制），`MediaSession.Callback` 的 play/pause/seekTo/
  skipToNext/skipToPrevious → §4 统一流程（next/previous **不用** ExoPlayer 播放列表，
  队列真相在服务端）。
- manifest：`FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_MEDIA_PLAYBACK`、`INTERNET`、
  service 声明 `foregroundServiceType="mediaPlayback"`；application
  **`android:usesCleartextTraffic="true"`**（或 networkSecurityConfig 放行内网段）。
- 音频焦点：`AudioAttributes` + `setHandleAudioBecomingNoisy(true)` +
  `setAudioAttributes(..., handleAudioFocus=true)`（media3 内建焦点处理覆盖 §5 大半，
  仅 duck 音量与"上报服务端"需自写钩子）。
- 通知被用户划掉 / 系统杀服务：视同 stop，上报 stopped（尽力而为）。
- 封面：media3 `MediaMetadata.artworkUri` 直填 coverUrl，加载交给库。

## 8. 工程脚手架

```
plugins/hmusic-audio/
├── src/{lib.rs, commands.rs, mobile.rs, desktop.rs}   # desktop.rs 全部返回 E_UNSUPPORTED（桌面走 HTMLAudio 后端，不会调到）
├── android/src/main/java/.../{AudioPlugin.kt, PlaybackService.kt, ServerClient.kt}
├── ios/Sources/{AudioPlugin.swift, PlayerCore.swift, NowPlaying.swift, ServerClient.swift}
├── guest-js/index.js        # 薄封装（可选，native/audio-native.js 直接 invoke 也行）
└── permissions/default.toml
```

- 生成：`cargo tauri plugin new hmusic-audio --android --ios`，Rust 侧命令用
  `run_mobile_plugin` 转发，无桌面实现。
- JS 侧 `src/native/audio-native.js` 实现 AudioBackend 接口（§1），`boot.js` 检测
  `platform === "ios" | "android"` 时 `setAudioBackend(NativeAudioBackend)` 并
  `configure({serverBase, token})`（token 来自 localStorage，登录/改密后重调）。

## 9. 验收矩阵（真机，两平台各过一遍）

- [ ] 前台点播出声；锁屏后**连续播 30 分钟**不断
- [ ] **锁屏中播完自动下一首**（JS 挂起，插件直连推进），回前台 UI 与服务端一致
- [ ] 锁屏面板：封面/题/歌手正确，播放暂停/上一曲/下一曲/进度拖动全部生效且服务端状态同步
- [ ] 来电 → 暂停；挂断 → 恢复（iOS shouldResume / Android 焦点回归）
- [ ] 拔耳机/断蓝牙 → 立即暂停
- [ ] 队列播到尽头 → 停止 + 通知清除，无崩溃无循环
- [ ] 音源 403/失效 → audio:error 提示，不假死
- [ ] 退出登录 → teardown 后无残留通知/会话
- [ ] http 明文服务器地址在两平台都能出声（ATS/cleartext 配置生效）
- [ ] 网页端/桌面回归：HTMLAudio 后端行为与重构前逐项一致（进度不回跳、手势解锁仍必要）

## 实现状态
- [ ] main.js 后端抽象合入 HMusic-Server
- [ ] 插件脚手架 + configure/load/play 最小闭环（先 iOS）
- [ ] 后台自续播（§4）
- [ ] 中断矩阵（§5）
- [ ] Android 侧
