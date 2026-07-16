# 04 · 逐屏 UI 结构 + 交互 + API

> 读者：写页面的人。每屏给：布局块（从上到下）/ 交互动作→API / 状态与轮询 / 特殊机制。
> 来源：`HMusic-Server/web/views/*.js` + `main.js`。Flutter 原生复刻其行为和视觉，不复用代码。

## 全局外壳（Web 参考：main.js）

- **路由**：go_router 定义 `player search queue playlists charts stats settings` + `login/connection/lyrics`；
  受保护页未登录跳 login，无 server base 跳 connection。
- **桌面外壳**：`Sidebar`（品牌 + 7 导航 + 用户名/退出）+ `content`（底部悬浮 mini 玻璃控制条，
  见 03；web 侧边栏内的 mini 播放态不复刻——桌面 mini 承载控制，不只指示）。
- **窄屏外壳**：`MobileTopBar`（品牌 + 退出）+ `content` + `MobileNav`（底部 7 图标）。
- **iOS 27 窄屏 chrome**：顶栏、底部导航、mini player 由 Swift/SwiftUI NativeGlassShell 覆盖在
  Flutter 内容层之上；动态高度和安全区回报给 Flutter。旧 iOS 使用系统 material 回退。
- **Android 窄屏 chrome**：结构与 iOS 一致，由 Flutter AdaptiveGlassShell 渲染；根据性能档位关闭
  动态模糊，但尺寸、交互和信息层级不得变化。
- **全局轮询**：应用前台时由 playback provider 每 3-10 秒刷新；后台正确性由 AudioHandler 承担。
- **应用状态**：Riverpod 分离 connection/auth/playback/queue，不创建万能 store。
- **Toast**：ScaffoldMessenger 全局出口，默认 3.2 秒。

### ★ Flutter 本机播放契约
后端把「本机播放」当虚拟设备（deviceId=`local-browser`）记账，Flutter 由全局
`HMusicAudioHandler` 出声：

- playback.state/streamUrl 变化时装载、播放、暂停或停止 `just_audio`。
- 每 3 秒 POST `/playback/local-report` 回写 player 的真实进度。
- completed → POST `/local-report {ended:true}` → 消费服务端返回值并继续下一曲。
- seek/play/pause/position/duration 全部经同一个 AudioHandler；无需 Web 手势解锁。
- streamUrl 保留 path/query，但 host 必须重绑定到当前 server base。
- UI 挂起后后台 handler 仍须独立完成 report、ended 和系统媒体按钮，详见 08。

---

## 屏 1 · 登录 login.js

- **布局**：居中卡片 `.login-card`（shadow-pop）= logo 图 + 副标题 + 用户名 + 密码 + 主按钮。
- **材质**：登录和连接表单保持高对比不透明面板；顶部品牌区可以使用轻玻璃背景，但输入框区域
  不做动态模糊，避免键盘弹出和弱背景下可读性波动。
- **二合一**：`store.initialized=false` → 「创建管理员」（setup）；否则「登录」（login）。
- **交互**：输入校验（用户名≥3、密码≥8）→ 提交 `POST /auth/setup|login` → setToken → refreshAuth → 跳 player。回车提交。
- **★ 客户端增量**：首屏若无 serverBase，先渲染「连接服务器」表单（输 `http://IP:8090`，
  `/system/info` 探活和 API 版本校验通过，再请求 `/auth/status`）。

## 屏 2 · 正在播放 player.js（桌面双栏，1023px 转单列）

- **桌面布局（≥1024）**：`.np-grid` = 左封面舞台 + 右歌词。
  - **左 .np-stage**：大封面（`aspect-ratio:1` max420 shadow-pop）+ 曲名(衬线26)/歌手·专辑/状态点 +
    进度条 + 单行主控。
  - **右 .np-lyrics**：同步歌词，当前行衬线放大加深，上下 mask 渐隐，`min-height:420 max-height:640`。
- **★ 窄屏单屏模式（≤1023，移动端规范交互，Flutter 照此实现）**：
  不内联歌词栏——封面限高（≤44vh），布局为「封面 → 曲名/歌手 → **染色歌词条** → 进度 → 主控」
  一屏放下（QQ 音乐同构），底部导航保持可见；**点歌词条或点封面 → 进独立歌词页（屏 2b）**。
  染色歌词条：当前句按行内播放进度左→右渐进填充（行级 LRC 时间戳线性估算：本行 timeMs 到
  下一行 timeMs 的占比）。**必须逐帧驱动**：web 用 rAF 每帧直写 `--fill`（绕过框架响应式；
  100ms 定时器只有 10fps 肉眼卡顿，CSS transition 则换行回扫/行末染不满——两坑都踩过）；
  Flutter 用 Ticker/AnimationController 驱动 ShaderMask。无歌词时显示「暂无歌词」。
  歌词本体即入口，不加额外按钮装饰。
  iOS 27 的底部主控可由 SwiftUI 原生液态玻璃控制面板承载；Flutter 向原生层发送播放状态、
  `seekEnabled` 和音量能力，原生按钮只回传 intent。Android 使用同尺寸 Flutter 玻璃控制面板。
  > 教训一：早期把桌面双栏直接塌缩成单列，歌词栏在手机上撑出一屏空白、导航被顶出视野——
  > 播放页是全站唯一需要移动专属交互模式的页面，勿再直接塌缩。
  > 教训二：全屏歌词第一版做成 overlay 浮层，被否——**独立路由页**才对：
  > 系统返回手势天然可退出、无 z-index/fixed 诡异问题。

## 屏 2b · 歌词页（`/lyrics`，窄屏专用沉浸式路由）

- **形态**：沉浸式独立页——外壳在该路由下**隐藏侧栏/顶栏/底部导航**（routes 表 `immersive: true`）。
  桌面（≥1024）访问自动跳回播放页（桌面已有双栏歌词）。
- **布局（上→下）**：头部（收起键 chevronDown + 曲名/歌手衬线居中，右侧等宽 spacer 保证绝对居中）
  / 全屏歌词滚动（复用歌词组件：当前行衬线放大、上下 mask 渐隐、行点 seek、自动跟随 +
  进页即定位当前行）/ 迷你播控（进度条可拖 + 上一曲·播放暂停·下一曲三键）。
- **材质**：歌词正文保持无玻璃的沉浸内容层；头部和底部迷你播控使用平台玻璃，滚动歌词可从其
  下方经过。开启“降低透明度”时切为不透明 panel，不改变可用空间。
- **进入/退出**：播放页点封面或歌词条 `push` 进入；收起键 `pop` 或**系统返回手势**退出。
  真路由天然维护历史，这是“页面优于浮层”的核心理由。
- **状态**：与播放页共享 `lyric-state.js` 歌词缓存（同曲不重复请求）；自带 1s 本地插值 +
  5s 服务端校准（与播放页同款双定时器）。
- **交互→API**：三键 → 统一 PlaybackCoordinator → `POST /playback/{previous|pause|resume|next}`；
  进度拖动/行点 → coordinator seek + `POST /playback/seek`。
- **单行主控**（五键对称）：收藏 / 上一曲 / 播放暂停(64px主键) / 下一曲 / 音量（悬浮展开滑块）。
- **交互→API**：
  - 播放暂停/上下曲 → PlaybackCoordinator + `POST /playback/{resume|pause|previous|next}`
  - 进度条拖动 onChange → AudioHandler seek + `POST /playback/seek {positionMs}`
  - 音量 onChange → `POST /playback/volume {volume}`
  - 收藏心 → 「我喜欢的音乐」歌单：无则先 `POST /playlists{name}`，再 `POST /playlists/:id/tracks` 或 `DELETE .../tracks/:itemId`
  - 歌词行点击 → seek 到该行 timeMs（`seekEnabled` 时）
- **状态/轮询**：`syncTimer 5s`（refreshPlayback + 校准进度/音量）+ `localTimer 1s`（本地插值推进进度/歌词）。
  本机播放时进度真相源是 `just_audio`，不用服务端 positionMs 校准（否则会回跳）。
- **歌词加载**：track 变化 watch → `POST /tracks/lyrics {track}`；当前行 = 最后一个 `timeMs<=pos` 的行 → smooth scrollIntoView center。

## 屏 3 · 搜索 search.js

- **布局**：标题 + 搜索栏（输入 + 主按钮）+ 结果列表（track-row）。
- **材质**：搜索输入主体保持不透明；滚动后顶栏可折叠为平台玻璃搜索 chrome。
- **状态放模块级**（keyword/tracks/searched）：切页再回来不丢，刷新才重置。
- **交互→API**：
  - 搜索（回车/按钮）→ `GET /search?q=`
  - 每行三键：播放 `POST /playback/play{track}` / 加队列 `POST /queue/items{track}` / 加歌单（开弹窗）
  - 加歌单弹窗（Modal）：列已有歌单 `GET /playlists` → 点选 `POST /playlists/:id/tracks`；或输入新名 `POST /playlists` 后再加曲。

## 屏 4 · 队列 queue.js

- **布局**：`播放队列(N)` + 清空按钮 / 模式 tabs（列表循环·单曲循环·随机·顺序）/ 曲目列表。
- **材质**：模式 segmented control 可使用平台玻璃；曲目行保持内容面，不逐行玻璃化。
- **当前曲**：`.queue-current` 行，序号显 ♪ 且标题/序号变青。
- **交互→API**：
  - 点行/播放键 → 一步 `POST /playback/play{track, queueIndex}`（服务端同步队列指针，
    禁止先调 `/queue/current` 再 play 的两步写法——会留下指针已改但播放失败的半成功态）+ refreshPlayback
  - 移除 → 前端过滤后 `PUT /queue{tracks,currentIndex,playMode}`（无单曲删接口）
  - 切模式 → `POST /queue/mode{playMode}`
  - 清空 → `POST /queue/clear`
- **加载**：页面 provider 首次激活时 `GET /queue`。

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
  - 首次加载 `GET /charts` → 有并发上限地预取 `GET /charts/:id` 填 Top3 预览（顺带焐热后端 6h 缓存）
  - 卡片 Top3 行点歌名 → 直接播（stopPropagation 防冒泡进详情）
  - 点卡片其他区 → 进详情（`GET /charts/:id`）
  - 详情行：播放 `POST /playback/play`（榜条目带 track 直接播；apple 榜 resolveEntry 先 `GET /search`）/ 加队列
  - 播放全部 → `POST /charts/:id/play`
- **状态**：`previews{}`（id→Top3，undefined=加载中，null=失败回退描述），全局防连点 `actingRank`。

## 屏 7 · 统计（成熟图表组件 + HMusic 主题，纯墨配色）

- **布局（从上到下）**：4 个大数字卡（衬线，总览+近30天增量）/ 听歌趋势折线(近30天) /
  听歌时段柱状(24段，峰值柱最深墨) / 来源平台环形图+图例 /
  Top艺术家条 / Top歌曲(可点播) / Top专辑条。
- **实现约束**：优先选维护良好的 Flutter 图表包处理坐标、手势、无障碍和动画；只对现成组件
  无法表达的品牌细节使用小型 CustomPainter，禁止自行重写整套图表引擎。
- **交互→API**：首次加载 `GET /stats`；Top 歌曲行播放 `POST /playback/play{track}`。
- **配色**：图表纯墨色灰阶，唯一青色是榜单播放次数计数 `.chart-count`（全站共享）。焦点用最深墨（`.peak/.lead`）。

## 屏 8 · 设置 settings.js（桌面双栏 / 窄屏两级）

- **桌面（≥860）**：左菜单常驻 + 右内容双栏；**窄屏**：菜单页 ↔ 子页。
- **材质**：窄屏子页导航使用平台玻璃；账号、密码、token、插件代码等表单使用不透明 panel。
- **菜单**四组七项，每行带实时摘要（登录态/设备数/插件数/曲目数/配置）：
  账号与设备（小米账号·播放设备）/ 音源与内容（LX插件·手工曲目）/ 播放与诊断（运行配置·链路诊断）/ 安全（修改密码）。
- **子页详情**：
  - **小米账号** settings-mi.js：状态卡 + 三通道 tab。
    - 扫码：`POST /mi/qr/start` → Flutter 本地二维码组件渲染 → 每 2s `GET /mi/qr/:id/status` 轮询 + 1s 倒计时。
    - 账号密码：`POST /mi/verification/start` → 需短信则 `/verification/:id/confirm` + `/resend`。
    - 导入会话：`POST /mi/session/import{webCredentials}`。
    - 退出：`POST /mi/logout`。页面/controller dispose 时清定时器。
  - **播放设备** DevicesSection：`GET /devices`；刷新 `POST /devices/refresh`；选默认 `/:id/select`；探测 `/:id/probe`。
  - **LX 插件** settings-sources.js SourcesSection：列表(开关/测试/编辑/更新/删除) + 三通道添加
    （订阅链接 `POST /lx-plugins/fetch` 拉取预填 / 文件选择器读取 .js / 粘贴代码）→ `POST /lx-plugins` 保存。
    开关/删除/测试/更新对应各端点（见 02 章 §13）。
  - **手工曲目** TracksSection：`GET /config` 读 manualTracks；增删走 `PATCH /config{manualTracks}` 全量替换。
  - **运行配置** ConfigSection：`GET/PATCH /config`（服务端名/音质/搜索策略/解析策略/自定义型号）。
  - **链路诊断** DiagSection：测试音 `POST /playback/test-tone` + TTS `POST /playback/speak`；3s 轮询 `/playback/state`。
  - **修改密码** SecuritySection：`POST /auth/password` → setToken 续签。

## 特殊机制汇总（客户端务必保留）
1. 本机播放所有入口统一走 PlaybackCoordinator/AudioHandler，禁止页面直接操作播放器。
2. Flutter 扫码页用本地二维码组件渲染 `loginUrl`，不加载远程脚本。
3. 队列删除用 PUT 整体替换（无单曲删接口）。
4. 模块级搜索状态（切页不丢）。
5. 设置页用 `LayoutBuilder` 在 860px 切桌面/窄屏两种布局。
