# 07 - 路线图与验收

> 阶段以可验证结果命名，不按页面数量虚报进度。P0 详细门禁见 09。
> 2026-07-31 按代码逐项核查回填：P0/P1/P2 多项此前已完成未勾；真机验收（前后台/
> 锁屏、音箱切换、iOS 玻璃壳、Android 玻璃滚动）已由用户确认通过。

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
- [~] 深浅色、手机/平板/桌面宽度逐屏对照 Web 参考（两套主题跟随系统、860 主断点
      与 web 对齐均已落地；逐屏截图对照未做）
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

## P4 - 桌面原生

- [~] macOS/Windows/Linux 音频后端 spike 与验收（macOS：audio_service/just_audio
      darwin 后端可用；Windows/Linux 未注册本机音频后端，当前仅可遥控服务端/音箱）
- [ ] 托盘、关窗驻留、窗口状态记忆（当前三平台关窗即退、窗口尺寸不记忆）
- [~] 媒体键和系统「正在播放」面板（macOS 已随 audio_service 生效
      MPNowPlaying/MPRemoteCommand；Windows SMTC / Linux MPRIS 未做）
- [ ] 键盘快捷键不干扰文本输入
- [ ] 开机自启和外链打开

## P5 - 分发

- [x] CI：Android、iOS 未签名 IPA、macOS、Windows、Linux 发布矩阵已接入 release workflow
- [x] Android APK/AAB、iOS unsigned IPA、macOS universal ad-hoc、Windows/Linux x64 便携包已有可复现脚本
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
      剩余：各平台安装包内下载安装、iOS App Store 通道）
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
| iOS 27 系统 API 与 Flutter 合成限制 | 原生材质无法正确采样 Flutter 背景 | P0 先做 SwiftUI overlay 真机 spike；失败时系统 material 回退 |
| Android 动态模糊耗电或掉帧 | 长列表体验变差 | chrome 共享模糊层 + High/Medium/Off 自动降级 |
| Swift 与 Flutter 状态双写 | 导航或播放状态冲突 | Swift 只展示并发 intent，Flutter 始终是业务状态源 |
