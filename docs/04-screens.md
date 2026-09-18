# 04 · 逐屏 UI 结构 + 交互 + API

> 读者：写页面的人。每屏给：布局块（从上到下）/ 交互动作→API / 状态与轮询 / 特殊机制。
> 来源：`HMusic-Server/web/views/*.js` + `main.js`。Flutter 原生复刻其行为和视觉，不复用代码。
> App 的导航、分栏与播放条已按 [13 全平台 UI 方案](13-ui-modernization-plan.md) 更新；
> Web 的页面结构仅作为行为参考，不能覆盖客户端实际路由和平台能力。

## 全局外壳（Web 参考：main.js）

- **路由**：go_router 定义 `player search queue playlists charts stats settings` + `login/connection/lyrics`；
  受保护页未登录跳 login，无 server base 跳 connection。
- **中屏/桌面外壳**：700–1023 使用 80 宽 rail，≥1024 使用 232 宽分组 `Sidebar`，
  保留七条 branch。底部 `DesktopPlaybackBar` 提供曲目/收藏、前后切歌/播放/进度、
  设备/音量/队列；小内容区或大字时多行，完整播放页不重复显示。
  内容按同一个高度函数预留播放条包络。额外 28 标题栏留白只用于 macOS；其侧栏继续透出窗后材质。
- **窄屏外壳**：无常驻顶栏（对齐 Apple Music）——顶部只有 `TopEdgeScrim` 滚动消融
  （状态栏区渐进模糊 + 轻提亮，内容透见不遮挡；off 档退不透明渐变），
  品牌见登录页、退出登录在设置菜单底部；
  `content` + 底部悬浮玻璃 chrome（mini 胶囊 + 原榜单/歌单/统计/设置四入口 dock）。
  向下滚收为「左侧当前导航圆钮 / 中间 mini / 右侧搜索圆钮」，向上滚立即展开。
  底部 chrome 高度由 Scaffold（extendBody）注入 body 的 MediaQuery padding，各页让位。
  mini 恢复基础高 50 的曲名/歌手两行，收起只留封面、曲名和播放；无曲目显示“未在播放”。
  设备选择在完整播放器中；高度随系统字号变化，大字或收缩空间不足时保持展开。
- **iOS 26+ 窄屏 chrome**：底部导航、mini player 由 Swift/SwiftUI NativeGlassShell 覆盖在
  Flutter 内容层之上；动态高度和安全区回报给 Flutter。iOS<26 走与 Android 相同的
  Flutter 毛玻璃回退壳。到 rail/sidebar 时隐藏 native 底栏与 mini，旋转时同步重算 inset。
- **Android 窄屏 chrome**：结构与 iOS 一致，由 Flutter AdaptiveGlassShell 渲染；根据性能档位关闭
  动态模糊，但尺寸、交互和信息层级不得变化。
- **全局轮询**：应用前台时由 playback provider 每 3-10 秒刷新；后台正确性由 AudioHandler 承担。
- **应用状态**：Riverpod 分离 connection/auth/playback/queue，不创建万能 store。
- **操作反馈**：成功使用状态变化或按钮原地 ✓；错误与导入结果使用就地 `HMusicInlineNotice`，
  不新增全局 toast，详见 03。

### ★ Flutter 本机播放契约
后端把「本机播放」当虚拟设备（deviceId=`local-browser`）记账，Flutter 由全局
`HMusicAudioHandler` 出声：

- playback.state/streamUrl 变化时装载、播放、暂停或停止 `just_audio`。
- 每 3 秒 POST `/playback/local-report` 回写 player 的真实进度。
- completed → POST `/local-report {ended:true}` → 消费服务端返回值并继续下一曲。
- seek/play/pause/position/duration 全部经同一个 AudioHandler；无需 Web 手势解锁。
- streamUrl 保留 path/query，但 host 必须重绑定到当前 server base。
- UI 挂起后后台 handler 仍须独立完成 report、ended 和系统媒体按钮，详见 08。
- Android/iOS/macOS 已有本机后端；Windows/Linux 暂禁用本机目标选择与音源装载，说明原因并
  保留音箱遥控。不得将上述契约误读为五端本机播放均已完成。

---

## 纯播放器功能边界（2026-09-18 工作树）

入口位于首次启动的连接页，无需先登录；首次选择、设置中切入及后续启动均直达首页（榜单 `/charts`）。
不强制打开音源设置，需要配置时由用户从设置进入。
已进入其他模式时从设置切换，不在榜单内容区放模式切换按钮。

| 保留 | 隐藏/不提供 |
|---|---|
| 榜单、推荐管理、搜索、曲目匹配 | Server 登录/初始化、安全/改密/账户删除 |
| 本机播放、歌词、进度、音量、队列、播放模式 | 小米账号、音箱发现/选择/控制/TTS/代理选项 |
| 本地歌单、收藏、歌单链接导入、播放统计 | NAS 曲库、服务器上传/扫描、服务器下载/自动归档 |
| 本机 LX 音源、手工直链、音质/搜索/解析偏好 | Server 升级、链路诊断、切换服务器、退出登录 |
| 关于与 App 更新、切换运行模式 | Spotify 个人榜与账号功能（公开榜保留） |

播放页与桌面条隐藏应用内设备切换按钮，状态行不再打开设备列表，原生输出路由也受限。
系统耳机/蓝牙音频输出不受影响，仍由操作系统管理。纯播放器不等同离线播放器：尚无手机
离线下载或扫描手机文件能力，在线搜索与 LX 解析仍需网络。

## 屏 1 · 登录 login.js

- **布局**：居中卡片 `.login-card`（shadow-pop）= logo 图 + 副标题 + 用户名 + 密码 + 主按钮。
- **材质**：登录和连接表单保持高对比不透明面板；顶部品牌区可以使用轻玻璃背景，但输入框区域
  不做动态模糊，避免键盘弹出和弱背景下可读性波动。
- **二合一**：`store.initialized=false` → 「创建管理员」（setup）；否则「登录」（login）。
- **交互**：输入校验（用户名≥3、密码≥8）→ 提交 `POST /auth/setup|login` → setToken → refreshAuth → 跳 player。回车提交。
- **★ 客户端增量**：首屏若无 serverBase，先渲染「连接服务器」表单（输 `http://IP:8090`，
  `/system/info` 探活和 API 版本校验通过，再请求 `/auth/status`）。
- **★ 局域网自动发现**：连接页开屏即发现，两级候选源 + 统一 `/system/info` 身份确认
  （独立短超时 ApiClient，先确认先显示，按 base 去重）：
  1. **mDNS 订阅**（主路径）：Server 自广播 `_hmusic._tcp`（bonsoir 订阅，iOS/macOS 需
     Info.plist 声明 `NSBonjourServices`），秒级、支持任意端口；
  2. **HTTP 扫段**（兜底）：mDNS 静默 2s 才启动，按 /24 并发探默认端口 8090——路由器禁
     mDNS、Linux 无 Avahi 等场景仍可用（此路径仅默认端口）。
  **发现优先的信息层级**：「附近的服务器」卡片紧随品牌区、点选即连（主路径）；手动
  表单默认折叠成 ghost 链接，仅「扫过且一无所获」时自动展开（`discoverCompleted`
  区分尚未扫过/扫完没找到，首帧不闪表单）；连接错误统一显示在两区之间。「重新扫描」
  常驻。设置菜单有「更换服务器」入口回本页（换网不重启）。未认证探测撞上陌生设备的
  401 不清 token（ApiClient 只在带凭据请求收到 401 时才失效会话）。

## 屏 2 · 正在播放（按可用内容宽高布局）

- **宽内容布局**：`PlayerBody` 在实际内容区足够宽高时使用左封面舞台 + 右歌词；
  系统大字时允许回到单栏。不能拿整机宽度代替扣除侧栏后的空间。
  - **左 .np-stage**：大封面（`aspect-ratio:1` max420 shadow-pop）+ 曲名(衬线26)/歌手·专辑/状态点 +
    进度条 + 单行主控。
  - **右 .np-lyrics**：同步歌词，当前行衬线放大加深，上下 mask 渐隐，`min-height:420 max-height:640`。
- **★ 手机与窄内容模式**：不内联独立歌词栏；封面按可用高度收缩，布局为
  「封面 → 曲名/歌手 → 设备状态 → 染色歌词条 → 进度 → 主控 → 音量」。
  手机 `/player` 为全屏 push，rail/sidebar 从 `/now` 进入；矮横屏可左右排布并滚动，
  360×640、844×390 及 2 倍字均须保持控制可到达，不能强制单屏造成溢出。
  **点歌词条或点封面 → 进独立歌词页（屏 2b）**。
  设备状态行（仅播放目标为音箱时占行，本机是默认心智不渲染）：StateDot + 「正在播放 · 客厅音箱」
  12.5px muted，整行可点弹**播放设备 sheet**；宽屏状态行常驻（同 web），同样可点。
  音量行行尾有 20px 输出钮（对齐 Apple Music 输出按钮位置逻辑，本机/遥控恒在——它是本机切去
  音箱的入口），点击弹同一设备 sheet：纯列表（勾选=默认设备、在线/离线、点选即切换，
  服务端停旧起新），暖纸底 modal，主控行保持 5 键不加塞。
  染色歌词条：当前句按行内播放进度左→右渐进填充（行级 LRC 时间戳线性估算：本行 timeMs 到
  下一行 timeMs 的占比）。**必须逐帧驱动**：web 用 rAF 每帧直写 `--fill`（绕过框架响应式；
  100ms 定时器只有 10fps 肉眼卡顿，CSS transition 则换行回扫/行末染不满——两坑都踩过）；
  Flutter 用 Ticker/AnimationController 驱动 ShaderMask。无歌词时显示「暂无歌词」。
  歌词本体即入口，不加额外按钮装饰。
  本轮完整播放器仍由 Flutter 渲染；所有控制复用同一 `PlayerViewModel/AudioHandler`，
  不改变后台播放生命周期。
  > 教训一：早期把桌面双栏直接塌缩成单列，歌词栏在手机上撑出一屏空白、导航被顶出视野——
  > 播放页是全站唯一需要移动专属交互模式的页面，勿再直接塌缩。
  > 教训二：全屏歌词第一版做成 overlay 浮层，被否——**独立路由页**才对：
  > 系统返回手势天然可退出、无 z-index/fixed 诡异问题。

## 屏 2b · 歌词页（`/lyrics`，窄屏专用沉浸式路由）

- **形态**：`/lyrics` 为独立全屏 push 路由，不承载侧栏/底部导航。
  宽内容播放器已内联歌词；窄内容或大字时仍可打开本页，窗口变化不强制重定向。
- **布局（上→下）**：头部（收起键 chevronDown + 曲名/歌手衬线居中，右侧等宽 spacer 保证绝对居中）
  / 全屏歌词滚动（复用歌词组件：当前行衬线放大、上下 mask 渐隐、行点 seek、自动跟随 +
  进页即定位当前行）/ 迷你播控（进度条可拖 + 上一曲·播放暂停·下一曲三键）。
- **材质**：歌词正文保持无玻璃的沉浸内容层；头部和底部迷你播控使用平台玻璃，滚动歌词可从其
  下方经过。开启“降低透明度”时切为不透明 panel，不改变可用空间。
- **进入/退出**：播放页点封面或歌词条 `push` 进入；收起键 `pop` 或**系统返回手势**退出。
  真路由天然维护历史，这是“页面优于浮层”的核心理由。
- **状态**：与播放页共享 `lyricViewModelProvider` 缓存及 `playbackPositionOf` 位置；
  本机取 just_audio 真值，音箱取现有远端进度投影，不另建 Widget 定时器。
- **交互→API**：三键 → 统一 PlaybackCoordinator → `POST /playback/{previous|pause|resume|next}`；
  进度拖动/行点 → coordinator seek + `POST /playback/seek`。
- **控制绑定**：与完整播放器复用 `PlayerSeekBar` 和 `PlayerTransportControls`，歌词页只显示
  前后切歌/播放暂停；设备不支持本机播放时同时禁用相关控制与歌词行 seek。
- **歌词加载**：track 变化 → `POST /tracks/lyrics {track}`；按当前 position 选择行，
  通过真实布局几何滚动到视口 0.4 锚点。

## 屏 3 · 搜索 search.js

- **布局**：标题 + 搜索框 + 结果列表（track-row）。App 搜索框为玻璃胶囊 +
  放大镜前缀（对齐 Apple Music），不搬 web 的独立主按钮——Enter/键盘搜索键提交，
  搜索中的进度反馈由结果区 spinner 承担。
- **材质**：搜索输入使用平台自适应玻璃胶囊；结果列表使用稳定内容面板，禁止逐行叠加
  BackdropFilter。iOS 内容层仍由 Flutter 合成，不冒充 UIKit 原生 Liquid Glass 控件。
- **状态放模块级**（keyword/tracks/searched）：切页再回来不丢，刷新才重置。
- **宽屏曲目行**：与 NAS 共用自适应行组件，按真实内容宽度展示歌曲、歌手/专辑、时长、来源，
  手机保留封面与两行信息；动作区固定宽度，长文字省略，未知字段不虚构。
- **交互→API**：
  - 搜索（回车/按钮）→ `GET /search?q=`
  - 点行播放 `POST /playback/play{track}`；行尾加队列 `POST /queue/items{track}`。
  - 下载按钮打开音质选择，交既有下载 VM 保存到服务器；提交中禁用，结果使用行内确认。

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

## 屏 5 · 曲库（歌单 / NAS 歌曲）

- **入口**：`/playlists` 保留路径，app 层 `MusicLibraryPage` 组合歌单与 NAS 两个 feature。
  根分段直接显示“歌单 / NAS 歌曲”，提供听歌统计入口；两边保持独立状态，NAS 首次访问才加载。
- **歌单列表**：导入/创建 + 歌单卡网格。卡片使用 id/name 确定的可辨识占位封面，
  主要动作为打开/播放；“删除歌单”进入更多菜单，保留二次确认。
- **详情**：`‹ 返回` + `播放全部` / 歌单名 / 曲目列表（`.track-cols` 双列，每行序号 + 信息 + 移除键）。
- **交互→API**：
  - 创建（Modal）→ `POST /playlists{name}`
  - 导入（Modal 粘贴链接）→ `POST /playlists/import{url}` → 页内报告导入 N 首及跳过明细
  - 打开详情 → `GET /playlists/:id`
  - 播放全部/从某首 → `POST /playlists/:id/play{startIndex}`（先 prime）
  - 删歌单 → `DELETE /playlists/:id`；移除曲 → `DELETE /playlists/:id/tracks/:itemId`
- **NAS 歌曲**：保留全部/歌手/专辑/文件夹、搜索、分页、上传和扫描；分组详情返回当前 NAS 根页。
  根分段切换不增加返回层级，隐藏分段不能拦截当前页面返回。
- 本轮不逐张请求歌单/专辑详情获取真实封面；数据任务见 13 §8。

## 屏 6 · 榜单 charts.js（卡片墙 ↔ 详情）

**2026-09-18 工作树更新**：首页精选改为按本机推荐偏好统一混排（覆盖下文旧版固定分区
说明）。发现榜单标题右侧“首页推荐管理”可开关单个榜单、拖动排序、恢复默认；保存后生效，
取消不改设置。至少保留一个推荐榜单，最后一项不可关闭，旧全关配置按当前目录补一项展示。
隐藏只影响精选，不改变平台完整目录；隐藏榜单不参与首页预取，已发请求
允许完成但不重新展示卡片。偏好跨重启与三种播放模式保留，不写服务端配置。

- 手机入口和页头为“找歌”，保留搜索胶囊；桌面独立入口为榜单，并提供刷新按钮。
- 封面保留方形比例，Top3 歌名和歌手分层；卡高随系统字号增大，桌面使用完整网格。

- **卡片墙**（2026-09-08）：已连接 Spotify 时首先显示“我的 Spotify 榜单”三个周期，
  下面为“发现榜单”。默认精选每来源一个榜（含家庭榜），通过 Spotify/网易云/QQ/Apple/HMusic
  筛选浏览完整目录，移除重复主推。来源标签单行排列，超出宽度时横向滑动。
  点选靠右的标签后自动平移，露出后续分类；首尾限位，仅移动标签行。
  Spotify 账号目前在 Server Web 设置中连接，App 原生账号页尚未接入；榜单页没有 Spotify 设置入口。
  卡片 = 48px 方封面 + 来源/时段 + 衬线榜名 + 可点播 Top3；整卡打开详情，没有重复“查看全部”。
  个人区手机横滑、桌面并列；发现区纵向网格。加载显示三行骨架，失败在卡内显示原因与重试。
- **详情**：`‹ 返回` + `播放全部`(任意非空榜；Apple 榜服务端搜索匹配后开播) / 榜名 / 描述 / 曲目列表（chart-rank 前三衬线加深；**当前播放的条目排名位换青绿均衡器图标**标识）。
- **交互→API**：
  - 首次加载 `GET /charts` → 最多两个请求并发预取所有个人榜和当前筛选可见榜，填 Top3。
    预览与详情复用同一个完整页面及在途请求；刷新代数和详情代数阻止迟到响应回写。
  - 卡片 Top3 行点歌名 → 直接播（stopPropagation 防冒泡进详情）
  - 点卡片其他区 → 进详情（`GET /charts/:id`）
  - 详情行：播放 `POST /playback/play`（榜条目带 track 直接播；apple 榜 resolveEntry 先 `GET /search`）/ 加队列
  - 播放全部 → `POST /charts/:id/play`（Apple 榜条目无 track：服务端逐条搜「歌名 歌手」匹配，
    首命中即替换队列开播，其余后台补进队列——按钮不等 50 次搜索）
- **状态**：`previews{}`（id→Top3，缺键=加载中，空列表=空记录，null=失败）、
  `previewErrors{}`（单卡错误）、`selectedSource`（默认精选），全局防连点 `actingRank`。

## 屏 7 · 统计（成熟图表组件 + HMusic 主题，纯墨配色）

- 手机从曲库进入 `/stats`，底栏选中曲库，显式返回与系统返回均回曲库；桌面保留独立侧栏入口。
- **布局（从上到下）**：4 个大数字卡（衬线，总览+近30天增量）/ 听歌趋势折线(近30天) /
  听歌时段柱状(24段，峰值柱最深墨) / 来源平台环形图+图例 /
  Top艺术家条 / Top歌曲(可点播) / Top专辑条。
- **实现约束**：优先选维护良好的 Flutter 图表包处理坐标、手势、无障碍和动画；只对现成组件
  无法表达的品牌细节使用小型 CustomPainter，禁止自行重写整套图表引擎。
- **交互→API**：首次加载 `GET /stats`；Top 歌曲行播放 `POST /playback/play{track}`。
- **配色**：图表纯墨色灰阶，唯一青色是榜单播放次数计数 `.chart-count`（全站共享）。焦点用最深墨（`.peak/.lead`）。

## 屏 8 · 设置 settings.js（桌面双栏 / 窄屏两级）

- **宽内容**：菜单宽 `240 * max(1, scale(14)/14)`，加两侧 32、间距 32、正文至少 480 后
  才形成双栏（基础字需 784、2 倍字需 1024 内容宽）；不足则菜单页 ↔ 子页。
  切窗口大小保留已选 section 与未提交表单输入。
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
    主要展示名称、在线状态、当前输出；本机能力门禁给出可理解的原因，内部型号不是主要说明。
  - **服务器下载**：查看已有任务、失败重试和删除；明确保存到已连接的服务器，不等同手机离线下载。
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
5. 外壳只负责 700/1024 三档导航；设置、播放器和曲目列用 `LayoutBuilder` 的实际可用空间。
