# 02 · 后端 API 全量契约

> 读者：写数据层的人。基址 `{SERVER}/api/v1`（`{SERVER}` = 用户填的 `http://IP:8090`）。
> 除标注「公开」外，全部需 `Authorization: Bearer <token>`。
> 错误统一格式：`{ error: { code, message, details } }`；HTTP 401 一律视为登录失效清 token。
> 来源：`HMusic-Server/src/app.ts` 路由表 + 各 `*.routes.ts` 的 Zod schema（本文逐条核对过）。

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
  streamUrl?: string;      // 仅「本机播放」虚拟设备：<audio> 直连的音频代理地址
  updatedAt: number;
}

HMusicQueue { sessionId; items: {id, track, addedAt}[]; currentIndex; playMode; updatedAt }
HMusicDevice { id; name; type?; isOnline; ip?; isDefault; capabilities{6 个 supportsXxx 布尔} }
HMusicSource { id; name; type:"manual"|"lx_js"; enabled; priority; config{defaultQuality}; health{status,message?,checkedAt?}; updatedAt }
HMusicPlaylistDetail { id;name;description?;trackCount;createdAt;updatedAt; items:{id,playlistId,track,position,addedAt}[] }
HMusicLyric { trackId; source; lrc; lines:{timeMs,text}[]; translatedLines:{timeMs,text}[]; updatedAt }
```

## 1. Auth `/auth`

| 方法 | 路径 | 认证 | 入参 | 出参 |
|---|---|---|---|---|
| GET | `/auth/status` | 公开 | — | `{ initialized, authenticated, user?{id,username} }` |
| POST | `/auth/setup` | 公开 | `{username(≥3), password(≥8)}` | `{ user, accessToken }` |
| POST | `/auth/login` | 公开 | `{username, password}` | `{ user, accessToken }` |
| POST | `/auth/password` | Bearer | `{currentPassword, newPassword(≥8)}` | `{ user, accessToken }`（换新 token 免重登） |

登录流程：`status.initialized=false` → 走 setup（首次创建管理员）；否则走 login。

## 2. Search `/search`

| GET | `/search?q=<kw>&source?=&page?=1&limit?=20(max50)` | → `HMusicSearchResult{query,source?,page,limit,total,tracks[]}` |

## 3. Playback `/playback`

| 方法 | 路径 | 入参 | 说明 |
|---|---|---|---|
| GET | `/state` | — | → HMusicPlaybackState |
| GET | `/events` | — | SSE：`event: playback.state\ndata: <state>`（一次性推当前态，可用于唤醒刷新） |
| POST | `/play` | `{track? \| clientTrack? \| url?, deviceId?, quality?, durationMs?, positionMs?}` | 三选一来源 |
| POST | `/test-tone` | `{deviceId?}` | 播 3 秒内置测试音 |
| POST | `/pause`·`/resume`·`/stop`·`/next`·`/previous` | — | → 新 state |
| POST | `/seek` | `{positionMs}` | 本机播放需前端另调 localSeek |
| POST | `/volume` | `{volume 0-100}` | |
| POST | `/mode` | `{playMode}` | |
| POST | `/speak` | `{text(1-200), deviceId?}` | TTS 播报 |
| POST | `/local-report` | `{state?, positionMs?, durationMs?, ended?}` | **本机播放专用**：<audio> 回写进度；`ended:true` 时服务端推进队列并回新 state |

## 4. Queue `/queue`

| GET | `/` | → HMusicQueue |
| PUT | `/` | `{tracks[]? \| clientTracks[]?, currentIndex?, playMode?}` 整体替换 |
| POST | `/items` | `{track? \| clientTrack?}` 追加 |
| POST | `/current` | `{index}` 只改指针（播放需再调 /playback/play） |
| POST | `/mode` | `{playMode}` |
| POST | `/clear` | — 清空 |

> 注：无「删单曲」接口。删除 = 前端过滤后用 `PUT /` 整体替换（见 queue.js removeAt）。

## 5. Playlists `/playlists`

| GET | `/` | → `{playlists: HMusicPlaylistSummary[]}` |
| POST | `/` | `{name(1-80), description?}` → `{playlist}` |
| POST | `/import` | `{url}` → `{playlist, imported, skipped{duplicate,emptyTitle,truncated}}` 导入 QQ/酷我/网易云 分享链接，≤500 首 |
| GET | `/:id` | → `{playlist: HMusicPlaylistDetail}` |
| PATCH | `/:id` | `{name?, description?}` |
| DELETE | `/:id` | — |
| POST | `/:id/tracks` | `{track? \| clientTrack?}` → `{playlist}` |
| DELETE | `/:id/tracks/:itemId` | → `{playlist}` |
| POST | `/:id/play` | `{startIndex?, playMode?, deviceId?}` 整单灌队列开播 |

「我喜欢的音乐」= 名为该字符串的普通歌单，首次收藏时自动创建（见 player.js）。

## 6. Charts `/charts`

| GET | `/` | → `{charts: {id,name,description,kind}[]}` kind: family\|netease\|qq\|apple |
| GET | `/:id` | → `{...summary, updatedAt, entries: ChartEntry[]}` |
| POST | `/:id/play` | `{startIndex?, deviceId?}` 整榜播放（仅条目带 track 的榜；Apple 榜返回 409 CHART_NOT_PLAYABLE） |

ChartEntry: `{rank,title,artist,album?,coverUrl?,playCount?,track?}`。
榜单 id：`family` / `wy-hot,wy-new,wy-soar,wy-origin` / `qq-hot,qq-new,qq-soar` /
`apple-cn,apple-us,apple-jp,apple-kr,apple-tw,apple-hk`。
family/wy-*/qq-* 的 entry 带 track（点了直接播）；apple-* 无 track（前端搜索匹配）。

## 7. Stats `/stats`

| GET | `/stats` | → `{stats:{overview,last30d,topArtists[],topTracks[],topAlbums[],sourceDist[],dailyTrend[],hourDist[]}}` |

- overview/last30d: `{totalPlays,uniqueTracks,uniqueArtists,activeDays,...}`
- topTracks 每项带 `track`（可点播）；dailyTrend 近 30 天补零 `{date:"MM-DD",count}`；hourDist 24 段 `{hour,count}`
- sourceDist `{source,label,count,percent}`

## 8. Tracks / Lyrics `/tracks`

| POST | `/tracks/resolve` | `{track? \| clientTrack?, quality?}` → HMusicResolvedTrack{track,url,quality,expiresAt?} |
| POST | `/tracks/lyrics` | `{track? \| clientTrack?}` → HMusicLyric |
| GET | `/tracks/:id/lyrics` | → HMusicLyric |

## 9. Devices `/devices`

| GET | `/` | → `{devices: HMusicDevice[]}` |
| POST | `/refresh` | 从小米账号刷新 → `{deviceCount}` |
| POST | `/:id/select` | 设默认 |
| POST | `/:id/probe` | 探测能力 |

## 10. Mi 小米账号 `/mi`

| GET | `/status` | → `{loggedIn, accountMasked?, ...}` |
| POST | `/qr/start` | → `{qrId, loginUrl, expiresAt}`（前端本地渲染二维码） |
| GET | `/qr/:id/status` | → `{status: pending\|success\|failed\|expired, message?}` 每 2s 轮询 |
| POST | `/verification/start` | `{account, password, captchaCode?}` → 登录成功`{loggedIn,deviceCount}` 或需短信`{verificationId,maskedPhone,smsStatus,expiresAt}` |
| POST | `/verification/:id/confirm` | `{code(4-12)}` |
| POST | `/verification/:id/resend` | → `{smsStatus}` |
| POST | `/session/import` | `{account, webCredentials{stsUrl \| serviceToken+userId}}` |
| POST | `/web-verification/start`·`/:id/complete` | 网页验证代理通道 |
| POST | `/logout` | — |

smsStatus: `recent`(最近发过) / `limited`(限频，建议扫码) / 其他(已发送)。

## 11. Config `/config`

| GET | `/` | → `{serverName, defaultQuality, searchStrategy, resolveStrategy, extraPlayMusicModels[], manualTracks[], lxPlugins[]}` |
| PATCH | `/` | 上述字段任意子集（manualTracks 全量替换；extraPlayMusicModels 型号大写字母数字） |

- defaultQuality: `128k\|320k\|flac\|hires`
- searchStrategy: `qqFirst\|kuwoFirst\|neteaseFirst`
- resolveStrategy: `originalFirst\|qqFirst\|kuwoFirst\|neteaseFirst`

## 12. Sources / LX 插件 `/sources`

| GET | `/` | → `{sources: HMusicSource[]}`（带 health） |
| GET | `/lx-plugins` | → `{plugins: {id,name,enabled,defaultQuality,sourceUrl?}[]}` |
| POST | `/lx-plugins` | `{id,name,code,enabled?,defaultQuality?,sourceUrl?}` 全量 upsert |
| POST | `/lx-plugins/fetch` | `{url}` → `{code, meta{name?,version?}}` 服务端代拉订阅脚本 |
| POST | `/lx-plugins/:id/update` | 按记住的 sourceUrl 重拉 |
| GET | `/lx-plugins/:id` | → `{code}` |
| DELETE | `/lx-plugins/:id` | — |
| POST | `/:id/test` | 加载测试 → `{message}` |

## 13. 音频代理 `/proxy`（前端无需直接调）

`streamUrl` 已由服务端拼好（`/api/v1/proxy/audio/<base64>`）。客户端本机播放直接把
`getServerBase() + streamUrl的path` 塞进 `<audio>.src` 即可（见 01 章决策 B/D）。

## 静态前端

`GET /app/` 由服务端 `@fastify/static` 伺服 `web/` 目录——**这是网页端入口，客户端不用**
（客户端走本地 `tauri://` 加载同步来的 src/）。仅说明二者同源一份代码。
