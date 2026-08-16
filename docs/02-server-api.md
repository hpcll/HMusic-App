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

| GET | `/system/info` | → `{name,version,apiVersion,minAppVersion,mode,publicBaseUrl,capabilities}`；连接页优先用它探活。`minAppVersion`（0.0.0/缺失 = 不强制）低于门槛的 App 进全屏强升页（`core/upgrade/`），换兼容服务器可解 |
| GET | `/system/test-tone.wav` | 公开 WAV，支持 Range；主要供 Server 诊断 |

`publicBaseUrl` 是 Server 对外生成音频 URL 的实时生效值（Server 会把回环/失效 IPv4 替换为
其当前局域网地址），不等于客户端实际连接地址，禁止据此覆盖用户填写的 server base。

### 1.1 升级（需登录，2026-08-16）

| GET | `/system/update` | 查 GitHub Release 最新版（5min 缓存）→ `{current,latest,hasUpdate,notes,publishedAt,url,deployMode,canSelfUpdate,updating}` |
| POST | `/system/update` | 一键升级：native 后台执行 `install.sh --update`；docker 经 hmusic-updater 守护容器（watchtower HTTP API）拉新镜像重建。→ `{started:true}`；缺守护/不支持 409（`UPDATE_DOCKER_MODE`/`UPDATE_NOT_SUPPORTED`，message 带手动命令） |
| GET | `/system/update/log` | → `{updating,log}`，`data/update.log` 尾部 8KB，升级失败排查用 |

触发后 Server 会短暂停止并以新版重启；客户端应轮询公开的 `/system/info` 直到 `version`
变化（成功）或超时（引导看 log）。GitHub 不可达时 GET 返回 502 `UPDATE_CHECK_FAILED`。

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
| POST | `/test-tone` | `{deviceId?}` | 播 3 秒内置测试音；与正常播放隔离（不写播放状态/不进队列），返回 `{deviceId, deviceName}`；服务端 3.5s 后补发 pause+stop 掐停设备端循环 |
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

| GET | `/status` | → `{loggedIn, sessionExpired, accountMasked?, ...}`；`?verify=1` 触发限频真校验（≥5min 一次，拉设备列表验 serviceToken，401 确证才翻状态，网络抖动保持快照） |
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

会话过期语义：任何真实小米调用（播放控制 ubus / TTS / 设备列表 / 探测 / 状态真校验）遇到
401 时，Server 当场落库 `sessionExpired=true` 并翻 `loggedIn=false`（保留 accountMasked 与
deviceId，重登复用设备标识降风控）；主动 `/logout` 清空该标记。客户端据此区分「登录已过期」
与「未登录」，过期后调用需会话的接口返回 409 `MI_SESSION_EXPIRED`（不再是 `MI_ACCOUNT_NOT_LOGGED_IN`）。

## 12. Config `/config`

| GET | `/` | → `{serverName, defaultQuality, searchStrategy, resolveStrategy, extraPlayMusicModels[], manualTracks[], lxPlugins[], announceTracks}` |
| PATCH | `/` | 上述字段任意子集（manualTracks 全量替换；extraPlayMusicModels 型号大写字母数字；announceTracks 布尔=音箱开播前播报歌名，默认 false） |

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

## 16. Library `/library`（NAS 本地曲库，P6/M1，2026-07-31）

| GET | `/library?search=&artist=&album=&folder=&limit=&offset=` | → `{items, total, scan, scrape}`；items 按 artist/title 排序，`limit≤200`。`folder=` 空串是合法值（根目录直属） |
| GET | `/library/groups?by=artist\|album\|folder` | 分类聚合 → `{groups: [{name, count}]}`；`name` 空串 = 未知歌手/未知专辑/根目录 |
| POST | `/library/scan` | 触发增量扫描（幂等，扫描中返回当前进度）→ `{scan}`；扫描完自动接一轮刮削 |
| POST | `/library/scrape` | 手动补刮封面/歌词（幂等）→ `{scrape}` |
| DELETE | `/library/:id` | 移出曲库 → `{deletedId}`；`origin=scan` 仅删记录不动原文件（目录仍在配置时重扫会回来），download/upload 连文件一起删 |

- `LibraryItem`：`{id, trackKey, origin: scan|upload|download, source, title, artist,
  album?, durationMs?, coverUrl?, folder, hasLyric, fileExt, byteSize, createdAt,
  updatedAt, track}`。
- 每条自带 `track` 形态（`url` 为签名本地代理地址），客户端直接 `POST /playback/play
  {track}` 即可播放——`resolveTrack` 对带 url 的 track 短路，免插件解析。
- `scan` 状态：`{status: idle|scanning|done|failed, added, updated, removed, skipped,
  startedAt?, finishedAt?, error?}`。启动时 Server 自动扫一轮。
- 扫描来源身份 `local:<路径哈希>` 稳定（重扫不换），歌单里存的本地曲目快照不断链；
  下载入库保留原平台 `source:sourceTrackId`，在线点播同曲自动命中本地文件。
- 存量目录经 `PATCH /config` 的 `libraryDirs: string[]`（绝对路径，最多 16 个）配置，
  只读扫描，永不改动用户原文件。扫描范围严格限于 `DATA_DIR/music` + `libraryDirs`。
- **封面/歌词刮削**：本地优先（内嵌封面 → 同目录 cover/folder/front/album.jpg →
  同名 `.lrc`），缺失部分回退在线音源按「歌名 + 歌手」匹配（标题歌手对不上宁可留空，
  不做错配）。`scrape` 状态：`{status: idle|running|done, total, filled, missed}`；
  条目状态 `pending|done|miss`，`miss` 不重复刮以免每轮扫描重复打网络请求。
- 本地曲目歌词经 `GET /tracks/:id/lyrics` 读取，命中曲库落库的 lrc；`source=local`
  不再走在线音源查询（音源侧查无此曲，只会白等超时）。
- `/proxy/local/:token` 的 token 兼容三种身份：曲库 trackKey / 曲库条目 id / 下载记录 id；
  内嵌封面经 `cover:<trackKey>` token 出流。

| POST | `/library/upload` | multipart 单文件（字段名 `file`，≤500MB，仅 mp3/flac/m4a/ogg/wav/aac）→ `{item}`（含 track，已入库） |

上传流式落盘（临时名 + 原子改名），读标签入库 `origin=upload`；同名文件自动加序号。

## 16.1 小爱语音接管 spike（M3，2026-07-31）

| GET | `/mi/conversation/probe?deviceId=` | 拉指定（缺省第一台）音箱最近 5 条对话 → `{device, records: [{query, time, requestId}], raw}` |

非公开接口（与 xiaomusic 同源），固件差异可能拿不到——`raw` 透出原始响应供真机
判断。records 可用即 M3 全量可行；不可用则 M3 改道。

## 静态前端

`GET /app/` 由服务端 `@fastify/static` 伺服 `web/` 目录——**这是网页端入口，客户端不用**
。Flutter 原生实现只把它作为行为与视觉对照，不加载或同步其中的 JavaScript/CSS。

## 上架相关 API 缺口

当前 Auth 只有 setup/login/password，没有账户删除能力。由于 App 内允许首次 setup 创建管理员，
正式上架前必须先通过 ADR 确认单管理员自托管系统的删除语义，再实现 Server API 和 App 内入口。
不能把“退出登录”或“联系支持”当成删除账户。
