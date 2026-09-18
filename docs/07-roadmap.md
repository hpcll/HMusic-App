# 07 - 路线图与验收

> 阶段以可验证结果命名，不按页面数量虚报进度。P0 详细门禁见 09。
> 2026-07-31 按代码逐项核查回填：P0/P1/P2 多项此前已完成未勾；真机验收（前后台/
> 锁屏、音箱切换、iOS 玻璃壳、Android 玻璃滚动）已由用户确认通过。
> 2026-09-17 补发布索引（见下）。**勾选状态仍是 09-10 的口径**，其后两个版本的实际
> 交付见索引与 `CHANGELOG.md`。

## 发布索引

版本逐条的变更事实以 `CHANGELOG.md` 为准；此表只作「哪个版本交付了哪条路线」的对照。

| 版本 | 日期 | 交付要点 |
|---|---|---|
| v0.1.1 | 08-28 | 公开发布所需的安装、贡献、安全和构建文档 |
| v0.1.2 | 08-28 | 修部分 Android 机型「能发现服务端但连接报错」（键值存储通道） |
| v0.1.3 | 08-28 | 修登录页卡在「处理中…」（安全存储通道失效时异常逃逸） |
| v0.1.4 | 08-29 | 修 Android 正式包插件全未注册（`tool/build_release.sh` 缺陷） |
| v0.1.5 | 08-30 | 修「只有先暂停上一首才能播下一首」 |
| v0.1.6 | 09-03 | App 内直接更新（下载并交系统安装器）、设置入口新版红点、按架构分包 |
| v0.1.7 | 09-03 | 修「App 自己发现不了新版」：回前台也查，节流收到 1 小时 |
| v0.1.8 | 09-15 | **直连模式上线**（P7 主体）、播放界面改版、就地反馈替代浮层 toast |
| v0.1.9 | 09-16 | 四个安卓包统一 `versionCode`（修降级拒装）、按架构挑包、构建号跳 4009 |

## P0 - 契约与最小纵切

产出：Flutter 工程可运行，Android/iOS 完成连接、鉴权、搜索与本机后台播放最小闭环。

- [x] 技术栈定案 Flutter，清理 Tauri 脚手架
- [x] 审计 Server/App，统一架构和音频文档
- [x] 冻结 Feature-first MVVM、文件拆分和依赖准入规范
- [x] Server `queueIndex` schema/test 已修复；客户端队列点播可直接发送 `queueIndex`
- [x] 生成五平台 Flutter 工程，`flutter analyze/test` 通过
- [x] 按 MVVM 补齐 connection/auth/player/search/queue 最小纵切，单文件和依赖门禁通过
- [x] server base 规范化、`/system/info` 探活、setup/login/401 基础路径
- [x] Track/Playback/Queue/Auth 核心 DTO 与 ApiClient 完整覆盖（Queue DTO + queue 仓库/门禁测试补齐）
- [x] 搜索 -> 本机点播 -> pause/seek -> local-report -> ended 下一曲完整 UI 验收
      （真机验收通过，2026-07-31）
- [x] iOS 编译修复：NativeGlassShellChannel.swift 登记进 Xcode 工程；Info.plist 补 UIBackgroundModes=audio
- [x] Android 后台播放前置：AudioServiceActivity + 前台媒体服务/媒体按钮清单声明
- [x] 真服务器集成测试（integration_test/live_server_test.dart）：macOS ✓、iOS 26.5 模拟器 ✓（system/info + 鉴权搜索）
- [x] streamUrl host 重绑定覆盖 `127.0.0.1` 返回值
- [x] iOS 26+ Swift/SwiftUI NativeGlassShell：系统 UITabBarController 液态玻璃 dock
      + mini 胶囊 + intent 通道（含 ready/layout 事件重放，防首帧丢失误用回退壳）；
      iOS 26 以下由 Flutter 玻璃壳回退；dock/mini/内容折射/旧壳回退真机验收通过
      （2026-07-31）
- [x] Android AdaptiveGlassSurface：High/Medium/Off 三档（高对比/减动效自动降
      off），dock/mini/toast/横幅/搜索胶囊共用；真机滚动验收通过（2026-07-31）
- [x] Android/iOS 真机前后台与锁屏最小验收（2026-07-31）
- [x] 冻结 App Store 首发功能边界、Demo Server 方案和公网 HTTPS/LAN HTTP 策略（ADR-0003）
- [x] 冻结 App Store 产品定位：NAS/家庭服务器个人音乐库客户端

## P1 - 核心播放器

- [x] 播放页封面、元数据、进度、音量、模式（封面矮屏自适应、200ms 实时进度、
      本机/远端音量分流、模式循环切换；歌词条 ShaderMask 按进度染色）
- [x] Android Impeller 重启（2026-09-04：小米 spike 通过——零花屏、滚动帧
      p95=2.38ms；附带 TopEdgeScrim 渐进模糊在 Android 生效；iQOO/Adreno
      复测通过前不发版，见 docs/06）
- [~] Android 液态玻璃 dock + 透镜胶囊（2026-09-04 尝试并**回退**：真机评审
      视觉不如常规毛玻璃——亮色白底前折射不可见、整面发白，透镜泡过抢；
      教训与重启条件记录在 docs/06，Impeller 保留为独立收益）
- [~] iOS 原生 dock 滚动收起（2026-09-04：tabBarMinimizeBehavior .never →
      .onScrollDown 已装机，待真机确认与 mini 胶囊/inset 联动，冲突则回退
      .never 并回填 docs/06）
- [ ] iOS 原生玻璃播放控制面板；Android 同构 Flutter 玻璃控制面板
      （现状：原生侧仅 mini 播控条，seek/dismiss intent 暂忽略；完整播放页为
      Flutter 实现且已随壳真机验收——是否仍需原生完整面板待产品决策）
- [x] 独立沉浸歌词页与同步滚动（/lyrics 路由；ensureVisible 0.4 定位 + 未物化行
      两段校正 + 行点 seek；无行级时间戳整段降级）
- [x] 队列点播、删除、清空、换模式，命令串行无竞态（一步 queueIndex 点播 +
      busyItemId 单飞；写操作统一互斥 isMutating，交错写在入口拒绝，
      2026-07-31 补齐并有 VM 测试）
- [x] 本机与小米音箱设备切换：点歌/playAll 跟随所选设备、远端时本机静默 + 5s
      轮询回读、音箱音量走 `/playback/volume` 拖动结束提交、遥控进度本地外推
      平滑推进；自动连播由 Server 播放看门狗保障（C-12）；播放页设备状态行 +
      音量行尾输出钮 + 设备选择 sheet；真机 + 真音箱验收通过（2026-07-31）
- [x] 直链失效按当前曲目和位置自动恢复一次（60s 去抖防循环；救不回暂停本机、
      回写 paused 如实收场；stale_url_recovery_test 全链路覆盖）
- [x] 冷启动展示 Server 恢复的暂停态与队列，resume 重新解析后从原位置继续
      （handler 就绪即拉状态，含冷启动接续音箱播放不等首轮轮询）

## P2 - 全功能页

- [x] 歌单创建、导入、详情、收藏、播放全部（导入支持 QQ/酷我/网易云分享链接并
      报告去重/截断统计；「我喜欢的音乐」首次收藏自动建同名歌单；「已下载」
      系统视图暂缓）
- [x] 榜单卡片墙、详情、整榜播放、Apple 榜搜索匹配（四来源分组 + Top3 预览预取；
      Apple 榜无快照条目按「歌名 歌手」搜索匹配；当前播放条目青绿均衡器标识）
- [x] 榜单重整（2026-09-08）：与 Web 共用 `/charts` Spotify 目录/详情/播放契约；
      三个个人常听榜首次加载即展示 Top3，预览与详情复用请求；个人区与发现区分层，
      平台筛选替代重复主推，卡内错误可重试，保留手机搜索与桌面刷新；商店版排除 Spotify。
      预取、切平台与详情共用两个请求名额，刷新丢弃旧响应并取消未发出的旧请求；
      409 个文件格式化、analyze 无问题、401 项全量测试及 iOS 模拟器 debug 构建通过。
      Server 真实接口三个个人榜各返回 50 首；Android ARM64 测试构建 2007 已通过飞书交付，
      收到用户实机首页反馈后，将平台标签改为单行横滑，避免手机换行占用过多高度。
      标签修正后 401 项测试、analyze、手机大字号及深浅色截图复核通过，签名相同的
      Android ARM64 测试构建 2008 已通过飞书交付，可覆盖旧测试包。
- [x] 统计图表（CustomPaint 自绘：30 天折线、24 小时柱状、来源环形、艺术家/专辑
      占比条、Top 曲目可点播；无图表库依赖）
- [x] 设置：账号、设备、音源、播放、服务器、安全（八区块全接真 API；改密码
      服务端换发新 token 免重登；另含下载管理、手工曲目、链路诊断子页）
- [x] App 内账户删除入口与 Server 删除语义/API（安全区块红色入口 + 密码二次
      确认 -> `DELETE /auth/account`，成功清会话回登录）
- [x] 服务端下载：搜索页触发（音质 sheet）、3s 状态轮询自动停表、失败重试、
      删除与大小展示
- [x] 小米扫码/短信/凭据登录流程（扫码本地渲码 + 2s 轮询 + 过期重试；密码登录
      含短信挑战/重发/取消；STS URL 或 serviceToken+userId 凭据导入）
- [x] 小米会话过期全链路（2026-07-26）：Server 401 确证落库 + `/mi/status?verify=1`
      限频真校验（C-13）；App 冷启/回前台检测 + 壳层常驻横幅深链设置、状态卡如实
      显示已过期；toast 升级 Apple Music 式胶囊（图标表意 + 淡入上浮，docs/03）
- [~] 全平台响应式与深浅色（2026-09-07）：外壳改为 700/1024 三档断点，
      内容按实际宽高布局；37 组 Flutter 组件预览及关键改前/改后截图复核通过。
      iOS 原生材质、Android 实机和 Windows/Linux 对应宿主验收仍单列，不能以截图替代
- [x] 全平台 UI 内容优化（2026-09-07；手机 dock 规格于 09-08 恢复，见 P3）：曲库根层切换
      歌单/NAS；保留原七分支、统计入口及逐级返回。搜索/NAS 共用曲目分列，榜单桌面
      网格、歌单稳定占位封面与更多菜单；NAS 工具/搜索/结果共同滚动，保留分页/上传/扫描。
      设置按内容宽度与字号分栏并保留未提交输入；下载文案明确保存到服务器。
      规格、分工与后续数据任务见 [13 全平台 UI 实施方案](13-ui-modernization-plan.md)
- [~] iOS 26+ 底栏/mini player 全量接入并真机验收，旧 iOS 回退完成（App 无常驻
      顶栏，顶部为滚动消融）；系统原生 sheet 未接——设备/音质等 sheet 为 Flutter 实现
- [x] Android 玻璃 chrome 全页覆盖，不玻璃化内容列表和卡片（FlutterGlassShell +
      AdaptiveGlassSurface，内容保持暖纸/墨色）

## P3 - 移动质量

- [ ] 08 章中断矩阵 Android/iOS 真机全过
- [ ] 锁屏 30 分钟、后台播完自动下一首、系统回收边界有记录
- [x] 封面滑动切歌、列表左滑操作、下拉刷新（2026-07-31：封面横滑按 docs/05
      阈值 60px + 80ms 跟手；队列/歌单详情行左滑删除，成功滑出、失败回弹；
      榜单墙/歌单列表/歌单详情/统计/队列全部接下拉刷新，榜单错误态改为
      可下拉重试；均有 widget/VM 测试）
- [ ] 弱网、Server 离线、切 Wi-Fi、token 失效均可恢复
- [ ] 启动、内存、耗电和音频卡顿基线
- [ ] iOS Liquid Glass 合成、Android 三档 blur 的帧时间与 GPU 基线
- [~] Reduce Motion、Reduce Transparency、深浅色和高对比度验收（玻璃层已按
      高对比/减动效自动降 off 档；逐项验收未做）
- [ ] Android 实体音量键遥控音箱 spike（MediaSession remote volume 通道）；
      iOS 无公开 API 明确不做（决议 2026-07-19，遥控音量用 App 内滑条）
- [x] 反馈与触达打磨（2026-09-06）：浮层 toast 全面移除，改 Apple 式就地反馈——
      行内操作 ✓ 原地确认（HMusicConfirmButton）、错误/不可见结果就地内联
      （HMusicInlineNotice）、状态自明的成功不出声（规格见 docs/03「操作反馈」）；
      行内图标按钮命中区 34→44（视觉不变）；播放页封面加载淡入 + 音符占位；
      榜单详情加载态统一 spinner；曲库搜索框对齐全站无描边输入规范
- [x] 交互安全与空态（2026-09-06）：清空队列加确认对话框；队列/歌单空态改
      可点行动按钮（去搜索 / 创建歌单）；设备选择 sheet 空态加重新扫描
- [x] 用户反馈纠正与测试包（2026-09-08）：发现分类点选后自动横移并露出相邻分类；恢复原四项 dock
      与 50 高的两行 mini，按 Apple Music 参考改为左导航/中 mini/右搜索的连续收放。
      向下滚收起、向上滚展开，保留空闲 mini 与大字回退。419 项测试、静态分析与逐帧截图通过，
      同签名 ARM64 测试包 2009 已发送飞书；真机动画手感仍待复验。
      证据与边界见 [纠正记录](reviews/2026-09-08-chrome-correction.md)。
- [x] 本轮 UI 集成审查（2026-09-07）：修复共享按钮外圈命中、读屏激活、默认设置
      表单缩窗丢失及 NAS 小屏遮挡；404 文件格式化、全仓 analyze、379 项测试通过。
      iOS 模拟器、Android debug APK、macOS 无签名构建通过；macOS 默认签名构建因本机
      缺少开发 profile 受阻。完整证据见 [最终审查记录](reviews/2026-09-07-ui-modernization-review.md)
- [ ] 本轮 UI 真机复验：iOS dock/输出/旋转 inset、大字号与收缩；Android 大字号/
      横屏/玻璃三档；Android/iOS 后台连播/锁屏/中断。既有 2026-07-31 验收保留为历史结果，
      不自动覆盖本轮变更，Adreno/Impeller 发布前门禁继续有效

## P4 - 桌面原生

- [~] macOS/Windows/Linux 音频后端 spike 与验收（macOS：audio_service/just_audio
      darwin 后端可用；Windows/Linux 未注册本机音频后端，当前仅可遥控服务端/音箱；
      2026-09-07 已集中增加本机选择/装载门禁和原因说明，对应宿主编译与遥控实测仍待完成）
- [x] 桌面完整常驻播放条（2026-09-07）：曲目/收藏、前后切歌/播放/进度、设备/音量/
      队列；窄窗口和大字使用多行及同源高度占位，沿用现有 handler，本机音量即时更新、
      远端松手提交。手机 mini 已按 2026-09-08 用户反馈恢复原两行，输出选择位于完整播放器
- [ ] 托盘、关窗驻留、窗口状态记忆（当前三平台关窗即退、窗口尺寸不记忆）
- [~] 媒体键和系统「正在播放」面板（macOS 已随 audio_service 生效
      MPNowPlaying/MPRemoteCommand；Windows SMTC / Linux MPRIS 未做）
- [x] 键盘快捷键（2026-09-06）：空格播控 / ←→ seek ±10s / ⌘Ctrl+←→ 切歌，
      挂 MaterialApp.builder 全路由生效；文本框聚焦不抢键（EditableText 先消费 +
      兜底判断），250ms 节流防长按连发刷远端指令
- [ ] 开机自启和外链打开

## P5 - 分发

- [x] CI：Android、iOS 未签名 IPA、macOS、Windows、Linux 发布矩阵已接入 release workflow
- [x] Android APK/AAB、iOS unsigned IPA、macOS universal ad-hoc、Windows/Linux x64 便携包已有可复现脚本
- [~] Windows x64 安装向导已接入 Inno Setup（下一次 Windows Release 需完成 CI 产物与安装/卸载验收）
- [ ] 签名、公证、隐私说明、局域网权限说明
- [ ] HTTPS 审核 Demo Server、审核账号、公版测试音频和 Review Notes
- [ ] 隐私政策、支持 URL、App Privacy/Data Safety、SDK privacy manifest
- [ ] 内容权利审查、商店版 LX/下载边界和发布区域决策
- [ ] TestFlight/Google closed test、账户删除、后台音频审核路径全过
- [~] 自动升级方案按各平台能力分别确定（2026-08-16：设置 →「关于与更新」上线——
      Server 升级检查 `/system/update` + 一键升级（native 部署后台跑
      `install.sh --update`，轮询 `/system/info` 确认新版）；App 自查 GitHub
      Releases 跳浏览器下载。2026-08-17：强制升级门——Server `minAppVersion`
      + 仓库 `app-config.json`（raw/jsDelivr 双镜像）双通道，命中押全屏强升页。
      剩余：各平台安装包内下载安装、iOS App Store 通道。2026-09-03：iOS 通道的
      App 侧骨架已通——`app-config.json` 新增 `iosUrl`（App Store/TestFlight 链接），
      「关于与更新」与强升页 iOS 分支直达商店、未上架只给说明并隐藏网盘入口；
      剩上架本身（TestFlight/App Store 过审后填链接）
- [x] README 安装、连接和故障排查（2026-08-26：App/Server 快速开始、部署、升级和常见问题已公开）

## P6 - NAS 曲库与语音接管

> 2026-07-31 立项定序；Server 侧方案细节见 HMusic-Server `docs/FEATURES.md` 第八节。
> 推进顺序：M1 曲库（+M3 spike 并行）→ M2 上传 → M3 全量。App 侧待 Server
> 契约落地后先更新 docs/02 再接入。

- [x] M1 Server（2026-07-31）：library 表 + music-metadata 标签/内嵌封面 + 扫描器
      （自管目录 + libraryDirs 存量目录只读，增量指纹、孤儿收编、失踪清理）+
      `/library` API + `/proxy/local` token 泛化（trackKey 稳定身份，重扫不断链）+
      下载完成自动入库 + 启动自动扫描；typecheck/test 通过
- [x] M1 App（2026-07-31）：歌单页「NAS 曲库」系统视图——列表↔曲库↔详情同页
      切换（壳的侧栏/dock 全程常驻，页头对齐歌单详情），分段「全部/歌手/专辑/
      文件夹」聚合浏览、搜索防抖、分页滚动加载、点播/加队列、下拉刷新、扫描；VM 测试
- [x] M1 刮削（2026-07-31）：本地优先（内嵌封面 → 同目录 cover/folder 图 → 同名
      `.lrc`）+ 在线音源按歌名歌手匹配兜底（宁缺毋滥，错配即拒），扫描后自动
      后台刮；本地曲目歌词经 `/tracks/:id/lyrics` 打通；匹配判定 7 例单测
- [x] M1 修复（2026-07-31）：macOS 本地曲库播放失败根因 = AVFoundation 拒绝
      mDNS 裸主机名（-1008），播放地址重绑定时解析成 IPv4；补 macOS ATS 局域网
      放行与 file_picker 沙箱 entitlement
- [~] M3 spike：`GET /mi/conversation/probe` 探测端点已就绪（xiaomusic 同源
      conversation 接口 + 原始响应透出）；**待真机验证**——拉不到则 M3 改道或作废
- [x] M2 Server（2026-07-31）：`POST /library/upload`（@fastify/multipart 单文件
      500MB 上限、扩展名白名单、流式落盘原子改名、ingest 复用扫描链）
- [x] M2 App（2026-07-31）：file_picker 多选音频 + 逐个上传（进度条 + 剩余计数、
      失败跳过继续）+ 完成自动刷新（iOS 仅支持文件形式，Apple Music DRM 库不可导出）
- [ ] M3 Server：conversation 轮询服务 + 指令解析 + 曲库优先搜歌 + 抢占播放 +
      可选 TTS 回执；开关与轮询间隔入 config
- [ ] M3 App：设置页语音接管开关与状态展示

- [~] Spotify 推荐（路线 B：个人自用非官方，2026-09-04 用户拍板）：
      Server 已落地——`/api/v1/spotify` 会话绑定（sp_dc→web player token，
      TOTP 算法对拍单测锁定）、Top 曲目/歌单/整单匹配播放（复用榜单播放
      纪律），typecheck+80 测试全过，契约见 docs/02 §7½；
      **2026-09-08**：App 榜单视图及 BuildEdition 排除路径已接入；Server 默认数据通道
      已为 Pathfinder，Web 账号连接在设置内。**待做**：App 原生账号管理、个人歌单视图，
      Discover Weekly 等生成歌单的发现入口。常听榜来自 Spotify，HMusic 播放记录不会
      自动补写到 Spotify；接口评估见 Server `docs/charts-and-account-integration.md`。

## P7 - 旧版直连模式迁移

> 用户要求从 `../HMusic` 移植到当前客户端，先方案再实施；完整设计与来源映射见
> [14 - 直连模式迁移方案](14-direct-mode-migration-plan.md)。服务器模式继续保留。

- [x] 2026-09-09：核对旧版与 App/Server 当前代码，完成迁移方案、功能矩阵和状态所有权设计。
- [x] 模式持久化、旧版型号策略、安全会话存储、MiNA 设备/ubus 传输和会话恢复。
- [x] 密码/图片验证码、App 内身份验证、serviceToken/passToken 导入、独立登录路由和设置切换；
      仅交接 App 内本次验证会话，不读取系统浏览器 Cookie，不另建原生短信登录。
- [x] 本机 LX 插件、三平台搜索/跨源解析/歌词、Range 音频代理及新旧曲目模型转换；
      QQ/酷我/网易云公开搜索各 30 条实测通过，真实 JSC 桥与独立 isolate 验证通过。
- [x] 稳定 RoutedPlaybackRepository 复用单一 AudioHandler，直连本机/音箱播放、五种队列模式、
      歌单、收藏、导入、网易公开榜单及本机最近 5000 条播放统计。
- [x] 模式 generation / 本机 epoch / 音箱播放归属保护、迟到响应与 401 隔离、资源关闭、
      Server 专属入口和 StoreEdition 门禁；全仓 516 项通过（3 商店专项跳过），
      StoreEdition 单独 3 项通过，analyze 无问题，530 个 Dart 文件格式检查 0 差异。
- [x] Android ARM64 debug 构建；macOS Release 配置免签名构建通过，缺少 Mac 开发签名 profile。
- [x] iPhone17 Pro Max / iOS 27.0：真实 LX → 代理 → AudioService/just_audio 集成通过，
      覆盖进度、暂停/seek/恢复、自动下一曲、单曲循环和切换停止；AOT 设备结果 passed。
      iOS Release 主程序签名构建成功并已恢复安装，详见 14 的验证记录。
- [x] 2026-09-09 验证码空白修复：区分小米 HTML 登录网页与图片验证码，补齐图片内容校验、
      同域跳转 Cookie、加载失败提示及刷新恢复；登录专项 29 项、全仓 526 项通过
      （3 商店专项跳过），analyze 无问题、534 个 Dart 文件格式检查 0 差异。
      iPhone 公开验证码两次加载、解码与实际显示通过，设备报告 passed；正常修复版已安装并启动。
      此项验证不等同于真实账号登录验收。
- [x] 2026-09-09 网页验证闭环：专用原生窗口接收小米 STS 回调和 HttpOnly Cookie，
      经既有 Passport/设备校验后安全保存并进入主页；取消、模式切换和迟到结果回归覆盖。
      登录专项 49 项、全仓 543 项通过（3 商店专项跳过），analyze 无问题。
      iPhone 实测原站页面加载、受控回调交接、窗口关闭/返回与临时 Cookie 清理；
      设备报告 passed，正常 iOS 修复版已安装并启动，详见 14。
- [x] 2026-09-09 至 09-10 对照旧 HMusic 恢复 Flutter 内嵌验证页，修正现有凭据优先顺序、
      网页 UA、HTTP 错误提示与加载/取消时序；新增 25 项回归，全仓 568 项通过
      （3 商店专项跳过），analyze 无问题。9 月 10 日 00:11 iPhone 内嵌页面与受控回调、
      清理、取消全部通过，截图已核对；00:14 已重新构建、签名检查、安装并启动正常修复版。
      真实账号登录仍待用户自行完成验证，详见 14。
- [~] 2026-09-10：已接入用户授权的临时账号密码预填；直连恢复 QQ/Apple/Spotify 公开榜及
      本机热播，共 17 榜；整榜首曲开播、后台保序补队列带代数保护。两种模式统一设置框架、
      摘要和宽窄屏布局，直连配置重新分组。音箱型号、media、状态解包、过期链接续播和
      自动下一首对照 Server 修正；全仓 605 项通过、3 项商店专项跳过，analyze 无问题。
      iOS 26.5 模拟器的原站预填、受控回调、公开榜单及设置布局验收通过；实体 iPhone
      因锁屏尚未完成本轮交互验收。02:31 已恢复安装最新正常版，签名校验通过；
      真实账号与音箱播放仍待实测，详见 14。
- [ ] Android/iOS 真机前后台、锁屏和音箱验收；如实记录 iOS 挂起时直连音箱连播限制。
      目前小米登录/控制/状态测试仍使用模拟传输，不能据此宣称真实账号/音箱验收通过。
- [~] 2026-09-10 歌词/续播复核：歌词主键尺寸与加载态、直接进歌词页的订阅、冷启动位置及
      系统媒体快照已修正；真实保存曲目的 320k 403 现进入音质/插件/平台回退。切模式保留
      两侧进度，移除重复音箱指令，状态订阅等待切换完成；切回 Server 自动接续，并修复
      不重播开场时无限等待。iOS 模拟器真实歌曲续播、歌词按钮及外部终止进程后重启通过；
      全仓 625 项、商店专项 3 项通过，analyze 无问题，590 个 Dart 文件格式检查 0 差异。
      正常 iOS Release 构建及签名深度校验通过；实体设备离线，安装返回 CoreDevice 1011，
      本轮真机仍待设备恢复连接，完整复核见 [播放与模式对照](reviews/2026-09-10-playback-mode-parity.md)。

## 2026-09-18 接续收口（工作树，未发布）

- [x] Android LX 引擎兼容修复：保留 64 MB 内存限制，初始化/HTTP/加密/异步回调/isolate 原生测试通过。
- [x] 免登录纯播放器入口、冷恢复、本机目标隔离、模式切换、共享本地数据及设置裁剪；
      不支持本机的平台在切换前拒绝，不暂停原音箱；商店版仍禁用。
- [x] Spotify 8 秒请求预算与取消、明确网络错误、持久榜单缓存、离线保存日期与恢复覆盖测试。
- [x] 网盘下载入口为带图标的 48 高描边按钮；保留 iOS 隐藏规则。
- [x] 全仓 650 项通过 / 4 商店专项跳过；商店专项 5 项通过 / 4 普通版跳过；
      Server 类型检查及 22 文件 / 146 测试通过。Android API 36 ARM64 模拟器的
      LX → 代理 → 原生音频、暂停/seek/自动下一曲/单曲循环/切换停止通过。
- [x] Android 正常 App 免登录进入音源设置、强制结束进程后直接恢复榜单；新 AVD 实网
      显示 Spotify Global Top 50 前三首与封面、网易热歌榜，截图已查看。
- [~] 本轮平台安装复验：Android 17 真机 `0.1.9+4009` Release 覆盖安装、榜单/Spotify/推荐管理、
      Release 直连音频测试通过；macOS universal Release 构建、临时签名、安装启动和榜单 UI 通过；
      iOS 模拟器 LX/音频集成通过。iPhone 真机代码编译完成，但 Xcode 缺开发者账号与 profile，
      未安装；iOS 真机后台/锁屏及中断仍待完成。
- [ ] 本轮 Android/iOS 真机后台、锁屏及中断验收；第三方订阅真实曲目复验。
      不将模拟器/受控数据测试或此前真机结果替代本轮结论，也不保证全部 Spotify 网络可达。

- [x] 用户追加：首页推荐按榜单开关、拖动排序、保存/取消/恢复默认，本机跨重启持久化；
      精选统一混排，分类保留完整目录，隐藏项不参与首页预取。新增 5 项模型/存储/VM/组件测试，
      后续追加至少保留一项（UI/保存双校验、旧偏好兜底），以及纯播放器手机/桌面输出入口
      隐藏和状态行禁点、原生输出路由限制。全仓 657 项通过 / 4 跳过，包含 360px 两倍字号
      管理弹窗、最后一项限制和模式切回恢复设备入口；功能保留/隐藏表见 docs/04。

详见 [本轮验收记录](reviews/2026-09-18-player-lx-spotify.md)。未提交、未推送、未发布。

## 风险登记

| 风险 | 影响 | 对策 |
|---|---|---|
| Server 全局 `local-browser` 多客户端争用 | 状态互相覆盖 | P0 单活约束；后续设计 session/device identity |
| LAN HTTP 平台限制 | 无法连接或拉流 | P0 双真机提前验收 cleartext/ATS/local network |
| streamUrl host 为 127.0.0.1 | 手机无声 | ApiClient 统一按已连接 server base 重绑定 |
| 后台播放上下文与 UI 状态分叉 | 播完不续播、通知失真 | 唯一 AudioHandler，持有 API 能力，ended 在后台完成 |
| Server 与 App 并行演进 | 契约漂移 | 以冻结 commit 做集成测试；新端点先更新 02 再接入 |
| 桌面音频插件覆盖不齐 | 三平台体验不一致 | P4 前做 build/Range/seek spike，不提前绑定方案 |
| Flutter 与 Web 视觉漂移 | 产品不一致 | token 化 + 逐屏截图对照，不共享实现代码 |
| iOS 系统玻璃 API 与 Flutter 合成限制 | 原生材质无法正确采样 Flutter 背景 | 按实际 SDK availability 与 capability 接入；本轮 overlay/旋转/inset 仍须真机复验 |
| Android 动态模糊耗电或掉帧 | 长列表体验变差 | chrome 共享模糊层 + High/Medium/Off 自动降级 |
| Swift 与 Flutter 状态双写 | 导航或播放状态冲突 | Swift 只展示并发 intent，Flutter 始终是业务状态源 |
