# 04 · 逐屏 UI 结构 + 交互 + API

> 读者：写页面的人。每屏给：布局块（从上到下）/ 交互动作→API / 状态与轮询 / 特殊机制。
> 来源：`HMusic-Server/web/views/*.js` + `main.js`。客户端复用这些视图，本文是行为说明书。

## 全局外壳（main.js）

- **路由**：哈希路由 `#/<name>`，7 页：`player search queue playlists charts stats settings` + `login`。
  `requiresAuth` 页未登录跳 login。
- **桌面外壳**：`Sidebar`（品牌 + 7 导航 + mini 播放态 + 用户名/退出）+ `content`。
- **窄屏外壳**：`MobileTopBar`（品牌 + 退出）+ `content` + `MobileNav`（底部 7 图标）。
- **全局轮询**：`setInterval(refreshPlayback, 10000)`——刷新侧栏 mini 播放态。
- **store**（reactive）：`ready authenticated initialized user playback toast`。
- **toast(msg,kind)**：全局，3.2s 消失。

### ★ 本机播放引擎（main.js，客户端必须原样复用）
后端把「本机播放」当虚拟设备（deviceId=`local-browser`）记账，真正出声是全局 `<audio>`：
- `syncLocalAudio()`：跟 playback.state 换源/播/停/音量。streamUrl 变化才换 src。
- `primeLocalAudio()`：**点播放按钮时在用户手势里先解锁 <audio>**（清空旧源 + 空 play()）。
  没有它，`/playback/play` await 之后的 play() 会被自动播放策略拦截（点了停在 0:00）。
  搜索/榜单/歌单/队列 每个点播动作都先调它。
- `startLocalReporting()`：每 3s POST `/playback/local-report` 回写真实进度。
- `ended` 事件 → POST `/local-report {ended:true}` → 服务端推进队列 → 立即接着放。
- `localSeek/localPlay/localPause/localPositionMs/localDurationMs`：播放页直接操作 <audio>。
- **客户端差异**：streamUrl 要用 `getServerBase()+path`（见 01 章决策 B/D）。
- **移动端差异**：引擎的「出声后端」换成原生播放器（01 章决策 E + 06 章 M4 插件），
  编排逻辑（换源/回写/ended 推进）不变；prime 在原生后端为 no-op。

---

## 屏 1 · 登录 login.js

- **布局**：居中卡片 `.login-card`（shadow-pop）= logo 图 + 副标题 + 用户名 + 密码 + 主按钮。
- **二合一**：`store.initialized=false` → 「创建管理员」（setup）；否则「登录」（login）。
- **交互**：输入校验（用户名≥3、密码≥8）→ 提交 `POST /auth/setup|login` → setToken → refreshAuth → 跳 player。回车提交。
- **★ 客户端增量**：首屏若无 serverBase，先渲染「连接服务器」表单（输 `http://IP:8090`，探活 `/auth/status` 通过才进）。

## 屏 2 · 正在播放 player.js（桌面双栏，1023px 转单列）

- **布局**：`.np-grid` = 左封面舞台 + 右歌词。
  - **左 .np-stage**：大封面（`aspect-ratio:1` max420 shadow-pop）+ 曲名(衬线26)/歌手·专辑/状态点 +
    进度条 + 单行主控。
  - **右 .np-lyrics**：同步歌词，当前行衬线放大加深，上下 mask 渐隐，`min-height:420 max-height:640`。
- **单行主控**（五键对称）：收藏 / 上一曲 / 播放暂停(64px主键) / 下一曲 / 音量（悬浮展开滑块）。
- **交互→API**：
  - 播放暂停/上下曲 → `POST /playback/{resume|pause|previous|next}`（本机播放先在手势里 localPlay/localPause）
  - 进度条拖动 onChange → `POST /playback/seek {positionMs}`（本机再 localSeek）
  - 音量 onChange → `POST /playback/volume {volume}`
  - 收藏心 → 「我喜欢的音乐」歌单：无则先 `POST /playlists{name}`，再 `POST /playlists/:id/tracks` 或 `DELETE .../tracks/:itemId`
  - 歌词行点击 → seek 到该行 timeMs（`seekEnabled` 时）
- **状态/轮询**：`syncTimer 5s`（refreshPlayback + 校准进度/音量）+ `localTimer 1s`（本地插值推进进度/歌词）。
  本机播放时进度真相源是 `<audio>`（localPositionMs），不用服务端 positionMs（会每 5s 回跳）。
- **歌词加载**：track 变化 watch → `POST /tracks/lyrics {track}`；当前行 = 最后一个 `timeMs<=pos` 的行 → smooth scrollIntoView center。

## 屏 3 · 搜索 search.js

- **布局**：标题 + 搜索栏（输入 + 主按钮）+ 结果列表（track-row）。
- **状态放模块级**（keyword/tracks/searched）：切页再回来不丢，刷新才重置。
- **交互→API**：
  - 搜索（回车/按钮）→ `GET /search?q=`
  - 每行三键：播放 `POST /playback/play{track}`（先 primeLocalAudio）/ 加队列 `POST /queue/items{track}` / 加歌单（开弹窗）
  - 加歌单弹窗（Modal）：列已有歌单 `GET /playlists` → 点选 `POST /playlists/:id/tracks`；或输入新名 `POST /playlists` 后再加曲。

## 屏 4 · 队列 queue.js

- **布局**：`播放队列(N)` + 清空按钮 / 模式 tabs（列表循环·单曲循环·随机·顺序）/ 曲目列表。
- **当前曲**：`.queue-current` 行，序号显 ♪ 且标题/序号变青。
- **交互→API**：
  - 点行/播放键 → `POST /queue/current{index}` 改指针 + `POST /playback/play{track,queueIndex}`（先 prime）+ refreshPlayback
  - 移除 → 前端过滤后 `PUT /queue{tracks,currentIndex,playMode}`（无单曲删接口）
  - 切模式 → `POST /queue/mode{playMode}`
  - 清空 → `POST /queue/clear`
- **加载**：onMounted `GET /queue`。

## 屏 5 · 歌单 playlists.js（列表 ↔ 详情二级）

- **列表**：页头（导入歌单 + 创建歌单 两按钮）+ 歌单卡网格（`playlist-grid` auto-fill minmax300）。
  卡片：图标 + 名 + N首 + 播放/删除键。
- **详情**：`‹ 返回` + `播放全部` / 歌单名 / 曲目列表（`.track-cols` 双列，每行序号 + 信息 + 移除键）。
- **交互→API**：
  - 创建（Modal）→ `POST /playlists{name}`
  - 导入（Modal 粘贴链接）→ `POST /playlists/import{url}` → toast 报告导入 N 首 + 跳过明细
  - 打开详情 → `GET /playlists/:id`
  - 播放全部/从某首 → `POST /playlists/:id/play{startIndex}`（先 prime）
  - 删歌单 → `DELETE /playlists/:id`；移除曲 → `DELETE /playlists/:id/tracks/:itemId`

## 屏 6 · 榜单 charts.js（卡片墙 ↔ 详情）

- **卡片墙**：按来源分组（本站/网易云/QQ/Apple），每组卡片网格（`chart-wall` auto-fill minmax230）。
  **卡片 = 卡头(#1封面 44px + 衬线榜名) + Top3 预览(可点播) + 「查看全部 ›」**。
- **详情**：`‹ 返回` + `播放全部`(仅带 track 的榜) / 榜名 / 描述 / 曲目列表（chart-rank 前三衬线加深）。
- **交互→API**：
  - onMounted `GET /charts` → 并发预取每个 `GET /charts/:id` 填 Top3 预览（顺带焐热后端 6h 缓存）
  - 卡片 Top3 行点歌名 → 直接播（stopPropagation 防冒泡进详情）
  - 点卡片其他区 → 进详情（`GET /charts/:id`）
  - 详情行：播放 `POST /playback/play`（榜条目带 track 直接播；apple 榜 resolveEntry 先 `GET /search`）/ 加队列
  - 播放全部 → `POST /charts/:id/play`
- **状态**：`previews{}`（id→Top3，undefined=加载中，null=失败回退描述），全局防连点 `actingRank`。

## 屏 7 · 统计 stats.js（手写内联 SVG，纯墨配色）

- **布局（从上到下）**：4 个大数字卡（衬线，总览+近30天增量）/ 听歌趋势折线(近30天SVG) /
  听歌时段柱状(24段SVG，峰值柱最深墨) / 来源平台环形图(SVG stroke-dasharray)+图例 /
  Top艺术家条 / Top歌曲(可点播) / Top专辑条。
- **交互→API**：onMounted `GET /stats`；Top 歌曲行播放 `POST /playback/play{track}`（先 prime）。
- **配色**：图表纯墨色灰阶，唯一青色是榜单播放次数计数 `.chart-count`（全站共享）。焦点用最深墨（`.peak/.lead`）。

## 屏 8 · 设置 settings.js（桌面双栏 / 窄屏两级）

- **桌面（≥860）**：左菜单常驻 + 右内容双栏；**窄屏**：菜单页 ↔ 子页。
- **菜单**四组七项，每行带实时摘要（登录态/设备数/插件数/曲目数/配置）：
  账号与设备（小米账号·播放设备）/ 音源与内容（LX插件·手工曲目）/ 播放与诊断（运行配置·链路诊断）/ 安全（修改密码）。
- **子页详情**：
  - **小米账号** settings-mi.js：状态卡 + 三通道 tab。
    - 扫码：`POST /mi/qr/start` → 本地 `window.qrcode()` 渲染二维码 → 每 2s `GET /mi/qr/:id/status` 轮询 + 1s 倒计时。（★依赖 vendor/qrcode.js）
    - 账号密码：`POST /mi/verification/start` → 需短信则 `/verification/:id/confirm` + `/resend`。
    - 导入会话：`POST /mi/session/import{webCredentials}`。
    - 退出：`POST /mi/logout`。onUnmounted 清定时器。
  - **播放设备** DevicesSection：`GET /devices`；刷新 `POST /devices/refresh`；选默认 `/:id/select`；探测 `/:id/probe`。
  - **LX 插件** settings-sources.js SourcesSection：列表(开关/测试/编辑/更新/删除) + 三通道添加
    （订阅链接 `POST /lx-plugins/fetch` 拉取预填 / 选 .js 文件 FileReader 读入 / 粘贴代码）→ `POST /lx-plugins` 保存。
    开关/删除/测试/更新对应各端点（见 02 章 §12）。
  - **手工曲目** TracksSection：`GET /config` 读 manualTracks；增删走 `PATCH /config{manualTracks}` 全量替换。
  - **运行配置** ConfigSection：`GET/PATCH /config`（服务端名/音质/搜索策略/解析策略/自定义型号）。
  - **链路诊断** DiagSection：测试音 `POST /playback/test-tone` + TTS `POST /playback/speak`；3s 轮询 `/playback/state`。
  - **修改密码** SecuritySection：`POST /auth/password` → setToken 续签。

## 特殊机制汇总（客户端务必保留）
1. `primeLocalAudio()` 手势解锁——所有点播动作前必调。
2. 扫码依赖 `vendor/qrcode.js`（index.html 引入），缺失有降级提示。
3. 队列删除用 PUT 整体替换（无单曲删接口）。
4. 模块级搜索状态（切页不丢）。
5. 设置页用 `matchMedia("(min-width:860px)")` 切桌面/窄屏两种布局。
