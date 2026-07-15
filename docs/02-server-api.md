# 02 · 后端 API 全量契约

> 读者：写数据层的人。基址 `{SERVER}/api/v1`（`{SERVER}` = 用户填的 `http://IP:8090`）。
> 除标注「公开」外，全部需 `Authorization: Bearer <token>`。
> 错误统一格式：`{ error: { code, message, details } }`；HTTP 401 一律视为登录失效清 token。
> 来源：`HMusic-Server/src/app.ts` 路由表 + 各 `*.routes.ts` 的 Zod schema（2026-07-12 复核）。
> 审计基线：HMusic-Server main + 当前工作树（queueIndex/真探测/切设备同步/下载缓存/策略配置生效）。

## 0. 通用数据模型（src/shared/contracts.ts）

```ts
HMusicTrack {
  id: string;              // "source:sourceTrackId"
  source: string;          // tx(QQ) | kw(酷我) | wy(网易云) | manual | apple…
  sourceTrackId: string;
  title: string; artist: string;
  album?: string; durationMs?: number; coverUrl?: string;
  url?: string;            // 直链（手工曲目才有）
  qualities?: string[];    // ["128k","320k","flac"]
  raw?: unknown;           // 各平台解析所需原始字段，务必原样透传，勿裁剪
}

HMusicPlaybackState {
  sessionId: "default";
  deviceId?: string; deviceName?: string;
  state: "idle"|"loading"|"playing"|"paused"|"stopped"|"error";
  track?: HMusicTrack;
  positionMs: number; durationMs: number; volume: number;   // volume 0-100
  playMode: "list_loop"|"single_loop"|"shuffle"|"sequence"|"single_once";
  queueIndex: number; queueLength: number;
  seekEnabled: boolean;    // 当前设备是否支持进度跳转
  streamUrl?: string;      // 仅「本机播放」虚拟设备：原生播放器直连的签名音频代理地址
  updatedAt: number;
}

HMusicQueue { sessionId; items: {id, track, addedAt}[]; currentIndex; playMode; updatedAt }
HMusicDevice { id; name; type?; isOnline; ip?; isDefault; capabilities{6 个 supportsXxx 布尔} }
HMusicSource { id; name; type:"manual"|"lx_js"; enabled; priority; config{defaultQuality}; health{status,message?,checkedAt?}; updatedAt }
HMusicPlaylistDetail { id;name;description?;trackCount;createdAt;updatedAt; items:{id,playlistId,track,position,addedAt}[] }
HMusicLyric { trackId; source; lrc; lines:{timeMs,text}[]; translatedLines:{timeMs,text}[]; updatedAt }
DownloadRecord { id;trackKey;source;title;artist;album?;coverUrl?;track;quality?;
  status:"pending"|"downloading"|"done"|"failed";error?;byteSize;createdAt;updatedAt }
```

## 1. System `/system`（公开）

| GET | `/system/info` | → `{name,version,apiVersion,mode,publicBaseUrl,capabilities}`；连接页优先用它探活 |
| GET | `/system/test-tone.wav` | 公开 WAV，支持 Range；主要供 Server 诊断 |

`publicBaseUrl` 是 Server 对外生成音频 URL 的配置值，不等于客户端实际连接地址，禁止据此覆盖
用户填写的 server base。

## 2. Auth `/auth`

| 方法 | 路径 | 认证 | 入参 | 出参 |
|---|---|---|---|---|
| GET | `/auth/status` | 公开 | — | `{ initialized, authenticated, user?{id,username} }` |
| POST | `/auth/setup` | 公开 | `{username(≥3), password(≥8)}` | `{ user, accessToken }` |
| POST | `/auth/login` | 公开 | `{username, password}` | `{ user, accessToken }` |
| POST | `/auth/password` | Bearer | `{currentPassword, newPassword(≥8)}` | `{ user, accessToken }`（换新 token 免重登） |

登录流程：`status.initialized=false` → 走 setup（首次创建管理员）；否则走 login。

## 3. Search `/search`

| GET | `/search?q=<kw>&source?=&page?=1&limit?=20(max50)` | → `HMusicSearchResult{query,source?,page,limit,total,tracks[]}` |

## 4. Playback `/playback`

| 方法 | 路径 | 入参 | 说明 |
|---|---|---|---|
| GET | `/state` | — | → HMusicPlaybackState |
| GET | `/events` | — | 当前只发送一帧后断开，不是持续 SSE；P0 禁止依赖 |
| POST | `/play` | `{track? \| clientTrack? \| url?, deviceId?, quality?, durationMs?, positionMs?, queueIndex?}` | 三选一来源；队列点播必带 `queueIndex` 精确定位（同名歌可能出现多次） |
| POST | `/test-tone` | `{deviceId?}` | 播 3 秒内置测试音 |
| POST | `/pause`·`/resume`·`/stop`·`/next`·`/previous` | — | → 新 state |
| POST | `/seek` | `{positionMs}` | 本机播放还需让 `AudioHandler` seek |
| POST | `/volume` | `{volume 0-100}` | |
| POST | `/mode` | `{playMode}` | |
| POST | `/speak` | `{text(1-200), deviceId?}` | TTS 播报 |
| POST | `/local-report` | `{state?, positionMs?, durationMs?, ended?}` | **本机播放专用**：原生播放器回写；`ended:true` 时服务端推进队列并返回新 state |

> **S-P0-01 已修复**：`/playback/play` 的 strict schema 已声明 `queueIndex`（含重复歌曲
> index 0/1 回归测试）。客户端队列点播一步发送 `{track, queueIndex}` 即可，禁止再走
> 「先 `/queue/current` 再 play」两步——那会留下"指针改了但没播成"的半成功窗口。
> 仅在对接未修复的旧 Server 时按 12 的兼容矩阵降级。

## 5. Queue `/queue`

| GET | `/` | → HMusicQueue |
| PUT | `/` | `{tracks[]? \| clientTracks[]?, currentIndex?, playMode?}` 整体替换 |
| POST | `/items` | `{track? \| clientTrack?}` 追加 |
| POST | `/current` | `{index}` 只改指针（播放需再调 /playback/play） |
| POST | `/mode` | `{playMode}` |
| POST | `/clear` | — 清空 |

> 注：无「删单曲」接口。删除 = 前端过滤后用 `PUT /` 整体替换（见 queue.js removeAt）。

## 6. Playlists `/playlists`

| GET | `/` | → `{playlists: HMusicPlaylistSummary[]}` |
| POST | `/` | `{name(1-80), description?}` → `{playlist}` |
| POST | `/import` | `{url,name?}` → `{playlist, platform, platformName, imported, totalCount, skipped{duplicate,emptyTitle,truncated}}` 导入 QQ/酷我/网易云分享链接，≤500 首 |
| GET | `/:id` | → `{playlist: HMusicPlaylistDetail}` |
| PATCH | `/:id` | `{name?, description?}` |
| DELETE | `/:id` | — |
| POST | `/:id/tracks` | `{track? \| clientTrack?}` → `{playlist}` |
| DELETE | `/:id/tracks/:itemId` | → `{playlist}` |
| POST | `/:id/play` | `{startIndex?, playMode?, deviceId?}` 整单灌队列开播 |

「我喜欢的音乐」= 名为该字符串的普通歌单，首次收藏时自动创建（见 player.js）。

## 7. Charts `/charts`

| GET | `/` | → `{charts: {id,name,description,kind}[]}` kind: family\|netease\|qq\|apple |
| GET | `/:id` | → `{...summary, updatedAt, entries: ChartEntry[]}` |
| POST | `/:id/play` | `{startIndex?, deviceId?}` 整榜播放（仅条目带 track 的榜；Apple 榜返回 409 CHART_NOT_PLAYABLE） |

ChartEntry: `{rank,title,artist,album?,coverUrl?,playCount?,track?}`。
榜单 id：`family` / `wy-hot,wy-new,wy-soar,wy-origin` / `qq-hot,qq-new,qq-soar` /
`apple-cn,apple-us,apple-jp,apple-kr,apple-tw,apple-hk`。
family/wy-*/qq-* 的 entry 带 track（点了直接播）；apple-* 无 track（前端搜索匹配）。

## 8. Stats `/stats`

| GET | `/stats` | → `{stats:{overview,last30d,topArtists[],topTracks[],topAlbums[],sourceDist[],dailyTrend[],hourDist[]}}` |

- overview/last30d: `{totalPlays,uniqueTracks,uniqueArtists,activeDays,...}`
- topTracks 每项带 `track`（可点播）；dailyTrend 近 30 天补零 `{date:"MM-DD",count}`；hourDist 24 段 `{hour,count}`
- sourceDist `{source,label,count,percent}`

## 9. Tracks / Lyrics `/tracks`

| POST | `/tracks/resolve` | `{track? \| clientTrack?, quality?}` → HMusicResolvedTrack{track,url,quality,expiresAt?} |
| POST | `/tracks/lyrics` | `{track? \| clientTrack?}` → HMusicLyric |
| GET | `/tracks/:id/lyrics` | → HMusicLyric |

## 10. Devices `/devices`

| GET | `/` | → `{devices: HMusicDevice[]}` |
| POST | `/refresh` | 从小米账号刷新 → `{deviceCount}` |
| POST | `/:id/select` | 设默认 → `{selectedDeviceId, playback}`；同时把播放目标切到该设备（旧设备在播则暂停，状态转为新设备上的 paused，下次播放/续播按新设备重新解析） |
| POST | `/:id/probe` | 探测能力 → capabilities；小米已登录且非本机设备时先发真实 ubus 状态查询，会话过期/离线当场报错，不谎报正常 |

`POST /devices/mock` 是开发契约，不进入客户端 UI。

## 11. Mi 小米账号 `/mi`

| GET | `/status` | → `{loggedIn, accountMasked?, ...}` |
| POST | `/login` | `{account,password,captchaCode?,webCredentials?}` 兼容直登通道 |
| POST | `/qr/start` | → `{qrId, loginUrl, expiresAt}`（前端本地渲染二维码） |
| GET | `/qr/:id/status` | → `{status: pending\|success\|failed\|expired, message?}` 每 2s 轮询 |
| POST | `/verification/start` | `{account, password, captchaCode?}` → 登录成功`{loggedIn,deviceCount}` 或需短信`{verificationId,maskedPhone,smsStatus,expiresAt}` |
| POST | `/verification/:id/confirm` | `{code(4-12)}` |
| POST | `/verification/:id/resend` | → `{smsStatus}` |
| POST | `/session/import` | `{account, webCredentials{stsUrl \| serviceToken+userId}}` |
| POST | `/web-verification/start`·`/:id/complete` | 网页验证代理通道 |
| POST | `/logout` | — |

smsStatus: `recent`(最近发过) / `limited`(限频，建议扫码) / 其他(已发送)。

## 12. Config `/config`

| GET | `/` | → `{serverName, defaultQuality, searchStrategy, resolveStrategy, extraPlayMusicModels[], manualTracks[], lxPlugins[]}` |
| PATCH | `/` | 上述字段任意子集（manualTracks 全量替换；extraPlayMusicModels 型号大写字母数字） |

- defaultQuality: `128k\|320k\|flac\|hires`——点播与下载的首选档，取不到时逐档回退
- searchStrategy: `qqFirst\|kuwoFirst\|neteaseFirst`——聚合搜索结果的平台领先顺序
- resolveStrategy: `originalFirst\|qqFirst\|kuwoFirst\|neteaseFirst`——选某平台优先时，
  解析先在该平台匹配同一首歌取直链，失败回落歌曲原平台；originalFirst 只解析原平台
- lxPlugins 条目含 `sourceUrl?`（订阅链接）；GET 读出的对象可原样 PATCH 回去

## 13. Sources / LX 插件 `/sources`

| GET | `/` | → `{sources: HMusicSource[]}`（带 health） |
| GET | `/lx-plugins` | → `{plugins: {id,name,enabled,defaultQuality,sourceUrl?}[]}` |
| POST | `/lx-plugins` | `{id,name,code,enabled?,defaultQuality?,sourceUrl?}` 全量 upsert |
| POST | `/lx-plugins/fetch` | `{url}` → `{code, meta{name?,version?}}` 服务端代拉订阅脚本 |
| POST | `/lx-plugins/:id/update` | 按记住的 sourceUrl 重拉 |
| GET | `/lx-plugins/:id` | → `{code}` |
| DELETE | `/lx-plugins/:id` | — |
| POST | `/:id/test` | 加载测试 → `{message}` |

## 14. 音频代理 `/proxy`

`streamUrl` 是服务端拼好的签名地址（`/api/v1/proxy/audio/<token>`），代理本身无需 Bearer 且透传
Range。Flutter 必须保留返回 URL 的 path/query，并把 scheme/host/port 重绑定到当前 server base；
默认 `publicBaseUrl=127.0.0.1`，手机直接使用原 host 会访问自己。

## 15. Downloads `/downloads`

| GET | `/downloads` | → `{downloads: DownloadRecord[]}`，按创建时间倒序 |
| POST | `/downloads` | `{track? \| clientTrack?, quality?}` → `{download}`；后台下载，客户端轮询状态 |
| DELETE | `/downloads/:id` | 删除文件和记录 → `{deletedId}` |

完成的曲目播放时由 Server 自动优先命中 `/proxy/local/:token`，客户端仍消费普通 playback
`streamUrl`，无需识别本地/上游来源。下载管理不属于 P0 最小纵切，排入 P2。

## 静态前端

`GET /app/` 由服务端 `@fastify/static` 伺服 `web/` 目录——**这是网页端入口，客户端不用**
。Flutter 原生实现只把它作为行为与视觉对照，不加载或同步其中的 JavaScript/CSS。

## 上架相关 API 缺口

当前 Auth 只有 setup/login/password，没有账户删除能力。由于 App 内允许首次 setup 创建管理员，
正式上架前必须先通过 ADR 确认单管理员自托管系统的删除语义，再实现 Server API 和 App 内入口。
不能把“退出登录”或“联系支持”当成删除账户。
