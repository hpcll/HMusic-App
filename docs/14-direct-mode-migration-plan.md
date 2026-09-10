# 直连模式迁移：实现与验收

## 目标

把旧版 HMusic 中已经验证过的小米 IoT 直连能力迁移到 HMusic-App，使用户在没有
HMusic-Server 的情况下完成小米账号登录、设备发现、搜索解析、播放控制和本地数据管理。
服务器模式继续保留，二者共享播放器 UI、队列模型和现有 `HMusicAudioHandler`。
迁移来源为 `../HMusic`；落地仓库为本项目 `HMusic-App`，旧项目保持参考来源。

## 现状与边界

- HMusic-App 已接入 Server/direct 模式选择、独立登录路由和按模式选择的仓库；直连启动
  不探测 Server。连接页可直接进入，设置页可切换模式。
- 旧版 `MiIoTService`、`MiIoTDirectPlaybackStrategy`、直连账号、歌单/收藏和代理能力
  已按新版 `HMusicTrack`、仓库接口和 Riverpod 适配，没有搬入旧版万能 Provider。
- HMusic-Server 的 `/mi/*` 是“由 Server 代管小米会话”的服务器模式能力，不等价于客户端直连，
  直连适配器必须在 App 内持有小米会话并直接调用小米 IoT API。

## 已落地架构

```text
AppShell / PlayerViewModel
             |
     HMusicAudioHandler
             |
  RoutedPlaybackRepository
        /             \
 ApiPlaybackRepository   DirectPlaybackRepository
        |                         |
 HMusic-Server API          Xiaomi IoT API
```

复用已有 `PlaybackRepository`、`QueueRepository`、`DevicesRepository`、
`SearchRepository`、`PlaylistsRepository`、`LyricRepository` 接口，按活动模式选择实现。
不迁移旧 `PlaybackStrategy` 和 5000 行的 `PlaybackProvider`，也不建立第二个 AudioHandler。

### 模式与会话

`PlaybackModeController` / `PlaybackModeStore` 负责选择与恢复；Server token 与直连小米会话
分别存储。密码只用于当前认证请求和用户授权的本次小米原站表单预填，不落盘；`serviceToken`、`ssecurity` 和可选 `passToken`
通过 `SecureMiDirectSessionStore` 保存，不进入普通 preferences 或日志。

### 直连适配器

主要实现：

- `MiDirectAccountRepository` / `MiPassportClient`：密码、图片验证码、App 内身份验证、
  serviceToken 会话导入、passToken 交换、恢复与登出。导入先通过设备接口校验再保存；
  网页验证改为 App 内专用验证窗口，交接本次验证会话；不读取系统浏览器 Cookie，
  不另建原生短信登录。网络失败不当作认证失效。
- `DirectDeviceRegistry` / `DirectDevicesRepository`：设备列表、型号能力、目标选择和刷新。
- `DirectMusicSearch` / `DirectTrackResolver` / `DirectLxSources`：三平台搜索、跨源匹配、
  音质降级、插件运行和 URL 解析；`DirectLyricRepository` 负责歌词及插件兜底。
- `DirectPlaybackRepository`：实现现有播放接口，播放、暂停、恢复、切歌、seek、音量和状态。

`HMusicAudioHandler` 依赖稳定的 `RoutedPlaybackRepository`，切模式只改变路由目标，
不重复初始化系统 `AudioService`，ViewModel 不解释小米 API 字段。

### 音频与状态

直连音箱播放不启动本机 `just_audio`；本机播放仍由现有 `HMusicAudioHandler` 管理。
命令仍经现有 Handler 串行队列；直连仓库负责设备状态归一、队列推进和自动下一曲。代理 URL 采用：

`DirectAudioPolicy` 判定 CDN 和请求头要求；本机 HTTP 音频统一走 loopback 代理以兼容
AVFoundation ATS。音箱需代理时使用同网段 LAN IPv4，可手工指定本机可达地址；没有公共代理配置。
代理流式转发 Range/206、HEAD、长度和编码响应头，随机临时令牌映射已解析资源，不接受任意
URL 查询参数。令牌 6 小时过期、最多保留 128 个，模式退出后关闭监听并撤销映射。

`ModeStreamUrlRebaser` 已按模式分流：Server 继续执行签名路径校验和 host 重绑定，
直连保留已校验的来源/代理 URL；两种 URL 边界相互独立。

本机后台依然使用 `audio_service/just_audio`。直连音箱的连播由 App 计时/状态驱动，
iOS 挂起或用户结束 App 后不能承诺持续控制；不能用静音音频保活。前台恢复时读取设备事实并
核对播放实例，只推进一次，不补发挂起期间错过的多首切歌命令。恢复保留离开前的曲末 deadline，
丢弃跨生命周期的旧响应；冷启动核对安全存储 userId 与持久化 `ownerUserId` / audioId，
不能凭未加载的缓存账号或陌生设备播放推断归属。远端历史只在确认 playing 后记录。
需要无人值守音箱连播的场景继续使用服务器模式。

### 音源运行时

LX bootstrap 与 HTTP/MD5/AES/Buffer/timer/Promise 桥已迁移。每个插件运行在独立 isolate，
最多缓存 3 个实例；关闭时先通知 worker 释放 JSC/HTTP，1 秒无响应再终止 isolate。
插件初始化上限 15 秒、单次解析上限 10 秒，并服从整次解析的 45 秒预算；音质按支持能力降级，
跨平台候选需通过匹配校验。失败平台按连续失败计数后移，冷却后允许探测。

关闭或切模式增加 generation，排队请求和迟到结果不能复活已关闭的插件或 health 状态。
真实 JSC 已验证双实例互不串线、未完成 Promise 超时和有限忙循环；这不代表
`Isolate.kill` 能可靠中断任意原生无限循环，也不把 isolate 当作完整安全沙箱。

### 数据隔离

`DirectLocalStore` 的歌单、收藏、队列、音源、配置和历史使用独立本地命名空间，
与 Server 账户数据隔离；本地集合不宣称按小米账号分库。退出账号保留本地收藏/歌单，
播放归属仍按小米 userId 校验。

`PlaybackModeSwitch` 通过 Handler 串行切换：暂停旧目标并保存进度、关闭直连资源、清已装载音频及
媒体快照，再持久化新模式并触发会话/路由恢复。切回 Server 走正常 `/connect` 自动接续上次会话；
只有明确更换服务器才禁用自动接续。各模式保留自己的曲目、队列、进度、凭据和偏好，不自动开播。
本机已暂停时，旧 Server 离线/超时不阻断切换，并提示未能同步进度；无法确认音箱暂停时仍保留
原模式并显示错误。登出继续先停止目标再清安全会话。Handler 尚未观察到的直连目标由仓库控制，
已控制的目标不再重复发送暂停/停止。
Handler 同时核对模式 generation 与本机 epoch；`BackendRequest` 保护跨 await 的 ViewModel
结果，旧 pause/next/seek、组合命令和迟到 ended 不得作用于新后端。
播放状态订阅同样先进入 Handler 命令队列，避免模式通知早于旧快照清理时展示旧曲目或停在空态。
返回连接页且无需重播开场时，开场完成信号立即就绪，不让自动接续等待不存在的动画。

## 来源与目标映射

2026-09-10 的歌词、冷恢复、音质回退和模式往返复核及实测边界见
[播放与模式对照](reviews/2026-09-10-playback-mode-parity.md)。

| 旧版来源 | 新版落点及适配 |
| --- | --- |
| `presentation/providers/direct_mode_provider.dart` | 模式存储、独立直连登录 ViewModel；不迁移明文密码 preferences |
| `data/services/mi_iot_service.dart` | 按登录/设备/ubus 请求拆分；注入专属传输，不携带 Server Bearer |
| `mi_hardware_detector.dart` | `core/direct/mi_hardware_profile.dart`；按用户新要求对齐 Server 精确型号表（含 L06A/L15A/L16A/L17A），保留 OH2/P、S12A 固件暂停兼容 |
| `mi_audio_id_generator.dart`、`mi_play_mode.dart` | IoT 指令负载构建与播放模式映射，使用新版 Track 毫秒单位 |
| `mi_iot_direct_playback_strategy.dart` | `DirectPlaybackRepository`；保留状态保护、恢复和播放实例防重 |
| `native_music_search_service.dart` | `DirectSearchRepository`，QQ/酷我/网易云结果映射为 `HMusicTrack` |
| `song_resolver_service.dart`、`song_matcher.dart`、`platform_circuit_breaker.dart` | 直连解析服务；保留跨源匹配、平台 ID、音质、有限失败和熔断恢复 |
| `unified_js_runtime_service.dart`、LX preload 和运行器 | `IsolatedLxRuntime` / `FlutterLxRuntime`、LX bootstrap 与独立 HTTP/crypto bridge |
| `audio_proxy_server.dart`、`music_cdn_url_policy.dart` | 独立代理生命周期和 URL 策略；保留请求头、Range 及网络地址变化处理 |
| `direct_mode_playlist_service.dart`、收藏/导入服务 | 本地 PlaylistsRepository，使用新版曲目 ID 和歌单模型 |
| `lyric_service.dart`、`lyric_parser_service.dart` | 直连 LyricRepository，转换成新版行级毫秒歌词 |

业务传输分三类，页面禁止直接请求网络：

1. `ApiClient`：仅 Server，集中 base/Bearer/401；主客户端和 LAN 扫描客户端都检查活动模式。
2. `MiPassportHttp` / `MiMinaClient`：仅小米认证、设备和控制，集中 Cookie/签名/错误归一。
3. `DirectMusicHttp` / LX HTTP bridge / `DirectAudioProxy`：音乐平台、插件和音频资源，
   不继承 Server Bearer 或小米会话。

小米认证失效只清匹配的直连会话；音乐 CDN/平台错误不触发 Server 登录。
Server 旧模式的迟到 200/401/403 和旧 token 的 401 不写新状态、不清新 token。
非幂等设备命令不自动重发。

## 功能矩阵与页面接入

| 能力 | 服务器模式 | 直连模式 |
| --- | --- | --- |
| 启动 | 自动发现/Server 登录 | 恢复直连会话/小米登录 |
| 搜索、解析、歌词 | Server 仓库 | 本机搜索/插件/歌词仓库 |
| 播放设备 | Server 管理的小爱及本机 | 小米云设备及已支持音频后端的本机 |
| 队列、收藏、歌单及导入 | Server 持久化 | App 本地持久化，与 Server 完全隔离 |
| 音源配置 | Server 插件 | 本机插件导入、启停、测试、音质/代理设置 |
| NAS/Server 下载、运维、账号删除 | 原入口 | 不展示 Server 专属动作，禁止空 Server 请求 |
| 榜单 | Server 原能力 | 网易云 4 榜、QQ 3 榜、Apple Music 6 地区、Spotify 3 个公开榜及本机近 30 天热播，共 17 榜 |
| 统计 | Server 历史 | 仅本机最近 5000 条播放记录，页面明确范围 |
| Spotify 个人榜、Server 升级/账号管理 | 原能力 | 不复用 Server 的 Spotify 会话，个人榜及服务器专属入口不展示 |

连接页和设置已接入选择/切换，播放器、队列、歌单共享现有 UI 和 DTO；榜单与统计使用直连
仓库。设置共用分组菜单、实时摘要、窄屏子页与宽屏双栏；NAS、下载/运维、Server 账号删除、
Spotify 个人榜及 Server 会话提示按能力隐藏。

`BuildEdition` 在 UI 与仓库双重禁用商店版直连/本机脚本；即使 preferences 曾保存 direct，
商店版也恢复 Server。Android/iOS/macOS 保留本机音频路径；Windows/Linux 沿用
`ClientPlaybackCapabilities` 门禁，尚未验证其原生本机音频后端，不因为直连而提前开放。

## 实施完成度

- [x] 模式、持久化、路由、登录页面、验证码/会话导入与设备能力。
- [x] 三平台搜索、插件运行、跨源解析、歌词和音频代理。
- [x] 单一 Handler、本机/音箱仓库、五种队列模式、歌单/收藏/导入和本地统计。
- [x] 模式切换、迟到响应/命令、会话失效和资源释放回归。
- [x] Server 功能入口与 StoreEdition 门禁回归。
- [x] Android/iOS/macOS 原生构建及 iPhone 本机真实音频链路验证，记录见下。
- [ ] 真实小米账号/音箱、Android 真机、后台/锁屏长时间与中断验收。

## 验收标准

- 首次启动可选择直连模式，不配置 Server 也能进入直连登录。
- 登录成功后能看到设备并选择播放目标；搜索结果可在音箱播放。
- 播放、暂停、恢复、切歌、音量和状态同步可用；本机后台连播、音箱前台连播分别验证，
  音箱后台受操作系统挂起影响的行为必须实测并如实报告。
- 重启后模式、会话和设备选择可恢复；密码和 Token 不进入日志或普通偏好设置。
- Server 模式现有连接、鉴权、本机播放和远端音箱控制回归测试保持通过。

## 验证记录（2026-09-09）

| 检查 | 结果与边界 |
| --- | --- |
| `dart format .` | 530 个 Dart 文件，最终 0 差异 |
| `flutter analyze --no-pub` | 无问题 |
| `flutter test --no-pub --reporter expanded` | 516 通过、3 跳过；跳过项是商店版专项 |
| StoreEdition 指定测试 | 3 通过、2 普通版用例跳过，验证模式恢复、仓库脚本门禁与隐藏入口 |
| 真实公开搜索 | QQ/酷我/网易云各返回 30 条“晴天”结果，均含平台 ID |
| 真实 JSC | HTTP、MD5/AES、Buffer、timer、Promise、双 isolate 与关闭/超时验证通过 |
| Android ARM64 debug | 构建成功：`build/app/outputs/flutter-apk/app-debug.apk`；无连接的 Android 真机 |
| macOS Release 配置 | `CODE_SIGNING_ALLOWED=NO` 构建成功；本机缺少 Mac App Development profile，未完成签名分发验收 |
| iOS Release 主程序 | 签名构建及 `codesign --verify --deep --strict` 通过；`build/ios/iphoneos/Runner.app`（33.0 MB）已安装，截图确认榜单主界面与播放器正常显示 |
| iPhone 音频集成 | iPhone17 Pro Max / iOS 27.0（24A5424a），AOT 测试包实际执行，设备结果 `passed`、失败列表为空 |

真机集成测试位于 `integration_test/direct_audio_test.dart`。它使用内存会话/配置、本机
HTTP 合成 WAV 和真实 LX isolate，串起 resolver → proxy → AudioService/just_audio，
检查进度、暂停/seek/恢复、自动下一曲、单曲循环和切换停止，不读取用户的真实账号/曲库。
2026-09-09 20:09:26（Asia/Shanghai）完成，随后已恢复 `lib/main.dart` 的正常 App。
无线 `flutter drive` 的 VM 自动发现未成功，改为签名 AOT 测试包独立启动；从 App 临时目录
读取 `hmusic-direct-audio-result.json` 确认结果，不以构建成功或设备启动成功代替测试通过。
原始结果保存在 `build/verification/direct-audio-result.json`，测试包在
`build/verification/ios-direct-integration/Runner.app`，与正常主程序分开。
正常主程序的真机界面截图为 `build/verification/iphone-main.png`（20:24:30）；
此前等待无线调试连接时的白屏已不再出现。该截图验证恢复后的主界面，不替代真实小米登录验收。

小米认证、硬件请求及音箱状态的自动化目前使用模拟传输，不等同于真实账号/音箱验证。
公开搜索成功也不代表全部歌曲或第三方插件持续可用；后台/锁屏、音箱断网恢复、系统中断
与无人值守行为必须分别实测，不能据本机集成测试宣称通过。

复现命令：

```sh
dart format .
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter test --no-pub --dart-define=HMUSIC_STORE_EDITION=true \
  "test/core/playback/store_edition_direct_test.dart" \
  "test/features/connection/direct_entry_test.dart"
flutter build apk --no-pub --debug --target-platform android-arm64
xcodebuild -workspace "macos/Runner.xcworkspace" -scheme "Runner" \
  -configuration Release -derivedDataPath "build/macos" CODE_SIGNING_ALLOWED=NO build
flutter drive --no-pub --publish-port --no-keep-app-running \
  --driver "integration_test/driver.dart" --target "integration_test/direct_audio_test.dart" \
  -d "<iPhone UDID>"
```

无线 VM 自动发现不可用时，可用 AOT 包独立执行同一个测试并取回结果（完成后安装正常主程序）：

```sh
flutter build ios --no-pub --release --target "integration_test/direct_audio_test.dart"
xcrun devicectl device install app --device "<iPhone UDID>" "build/ios/iphoneos/Runner.app"
xcrun devicectl device process launch --device "<iPhone UDID>" --terminate-existing "com.hupc.hmusic"
xcrun devicectl device copy from --device "<iPhone UDID>" \
  --domain-type appDataContainer --domain-identifier "com.hupc.hmusic" \
  --source "tmp/hmusic-direct-audio-result.json" --destination "/tmp/hmusic-direct-audio-result.json"
```

结果的时间必须对应本次运行，且 `status` 为 `passed`；中途的 `started`、`initialized`
或播放阶段标记均不算通过。AOT 下控制台未必转发 Dart 日志，设备结果文件是验收依据。

### 验证码空白修复（2026-09-09）

真实公开 Passport 请求确认：`serviceLogin` 的 `location` 是 `/fe/service/login` HTML
登录页。旧逻辑在登录返回 70016 且未给出 `captchaUrl` 时，把该地址当成图片验证码，
再把 HTML 交给 `Image.memory`；图片解码失败且没有错误占位，导致验证码区域空白。

- `MiPassportExchange` 仅将 `/pass/getCode` 识别为图片验证码，其余小米验证网页沿用
  “打开小米验证页面”入口，由用户在浏览器继续操作。
- `MiPassportCaptcha` 单独处理最多三次同域 HTTPS 跳转并复用登录 Cookie，按文件头
  校验图片；小米实际返回 `application/octet-stream` 的 JPEG，不能仅按 MIME 拒绝。
  HTML、空内容和无效图片返回可重试错误，不改变 STS 换取 token 的跳转策略。
- 页面补齐加载、空图和解码失败提示；刷新前清除旧图，新图到达时清空旧验证码输入。
  传输、状态和显示各自处理本层职责，复用原登录流程，不新增 WebView 或认证框架。

| 检查 | 结果与边界 |
| --- | --- |
| 登录专项回归 | 29 项通过，覆盖网页/图片分流、跳转 Cookie、无效内容和刷新恢复 |
| 全仓测试 | 526 项通过、3 项商店版专项跳过 |
| 静态与格式检查 | `flutter analyze --no-pub` 无问题；534 个 Dart 文件格式检查 0 差异 |
| iPhone 验证码集成 | iPhone17 Pro Max / iOS 27.0，21:30:54（Asia/Shanghai）设备结果 `passed`，失败列表为空 |
| 实际图片显示与刷新 | 两次公开请求分别返回 2046 / 1974 字节，均解码为 125 × 42；真实 `DirectCaptchaImage` 的 `RawImage` 非空 |
| iOS Release 主程序 | `lib/main.dart` 构建成功（33.0 MB），`codesign --verify --deep --strict` 通过；21:34:46 已恢复安装并启动正常 App |

真机测试为 `integration_test/direct_captcha_test.dart`，设备原始结果已保存至
`build/verification/direct-captcha-result.json`。测试只请求公开验证码图片，不读取或提交
真实账号、密码或验证码答案；图片加载与显示通过不等同于真实账号登录成功。

### App 内网页验证交接（2026-09-09）

系统浏览器外跳无法把 Xiaomi 的 STS 回调和 Cookie 带回本 App，上一版“返回后重试”
不能保证登录闭环。本次使用专用 `MiWebVerifier` 平台适配器，在 App 内展示小米原站验证页：

1. 进入前清理本 App 专用 WebView 的旧验证 Cookie，并注入当前 Passport 事务 Cookie。
2. 用户自行完成网页登录/验证；原生 Cookie API 读取本次会话（含 HttpOnly），严格识别
   小米 HTTPS STS 主机和 `/sts` 路径，拦截回调后回到 Dart，避免回调被页面提前消费。
3. 复用 Passport 的 STS/passToken 交换和仓库设备列表校验，校验成功后安全保存并进入主页。
   关闭窗口视为取消；切模式、取消、迟到响应不能保存旧会话。结束时清理验证窗口 Cookie。

依赖为 `flutter_inappwebview 6.1.5`（Apache-2.0，稳定版；维护分支在 2026-02 有更新），
使用现成 Android WebView / iOS WKWebView / macOS 验证窗口及 Cookie API，不手写浏览器引擎。
本轮开启 Android/iOS/macOS，其他平台保留凭据导入并给出明确提示。关闭插件的 URL/控制台
调试日志；当时未预填密码，不记录回调参数、不访问 Safari Cookie，不增加设备权限。
2026-09-10 用户明确要求带入已填写的账号密码，当前临时预填边界见下文。
此窗口只承载小米认证；音乐 UI、导航、状态仍由 Flutter MVVM 持有，不恢复 WebView 客户端。
原生展示/交接、取消和会话保存分别验证，真实账号登录仍由用户亲自完成。

本次验收：

| 检查 | 结果与边界 |
| --- | --- |
| 登录专项回归 | 49 项通过，覆盖 STS/passToken、回调来源、Cookie 路径、重复点击、取消及回到 App 后进入主页 |
| 全仓测试 | 543 项通过、3 项商店版专项跳过 |
| 静态与格式检查 | `flutter analyze --no-pub` 无问题；542 个 Dart 文件格式检查 0 差异 |
| iPhone 原生验证窗口 | 22:14:03（Asia/Shanghai）设备报告 `passed`；公开小米登录页在 App 内完成加载 |
| iPhone 回调交接 | 本地 HTML 与测试 Cookie 验证 HttpOnly 读取、STS 拦截、关闭窗口、返回 Flutter、Cookie 清理和准备阶段取消；失败列表为空 |
| 正常主程序交付 | iOS Release 构建与签名校验通过；22:27:05 已覆盖安装并启动 `lib/main.dart` 正常 App |

当时真机用例为 `integration_test/direct_web_verification_test.dart`，历史结果保存在
`build/verification/direct-web-verification-native-window-20260909.json`。回调阶段使用受控测试数据，
不向小米提交真实账号、密码或验证码答案；不将其表述为真实小米账号登录成功。

### 恢复旧版验证页与凭据交接（2026-09-09 至 09-10）

用户反馈原生浏览器窗口样式与旧 HMusic 不一致，且登录出现统一的网络失败提示。
已对照旧项目 `captcha_webview_page.dart` 与 `mi_iot_service.dart`：

- 使用普通 Flutter 验证页，保留“小米账号验证”、关闭和刷新，主体内嵌原生 WebView；
  `RoutedMiWebVerifier` 只处理 App 路由，验证 ViewModel 处理导航、结果和重试。
- 与旧版一致，先接受已有 serviceToken，再使用 userId/passToken 交换，必要时才消费一次
  经过校验的 STS 回调；网页请求沿用移动浏览器 UA，SDK 交换保留 SDK UA。
- 仅在 Auth2 end / STS 完成点交接；普通页面出现 passToken 不提前关闭。
  加载结束事件不能抹掉加载错误，准备失败仍可重试，取消和临时 Cookie 清理保持串行。
- HTTP 拒绝保留脱敏状态码和阶段，与离线/超时分别提示，不记录 URL 参数或凭据。

本轮新页面与交接新增 25 项回归；全仓 568 项通过、3 项商店专项跳过，
`flutter analyze --no-pub` 无问题，554 个 Dart 文件格式检查 0 差异。
首次安装后设备锁屏以 `Locked` 拒绝启动；用户解锁后已补完本轮真机验收，
没有将旧版窗口报告用于新页面验收。2026-09-10 的结果如下（Asia/Shanghai）：

| 检查 | 结果与边界 |
| --- | --- |
| iPhone 内嵌验证页 | 00:11:33 设备报告 `passed`；公开小米登录页实际加载，移动 UA 与旧版一致 |
| 原生回调与清理 | 受控 HTML / HttpOnly Cookie 验证 STS 拦截、路由返回、WebView 销毁、临时 Cookie 清理；普通页面不提前完成；原生视图存在时取消与挂载前取消均通过 |
| 页面截图 | 已查看 `build/verification/direct-verification-page.png`，普通 App 标题、关闭/刷新与完整小米页面，未出现原生浏览器工具栏或白屏 |
| 正常主程序交付 | 重新构建 `lib/main.dart` iOS Release（36.0 MB），签名检查通过；00:14:23 已覆盖安装并成功启动 |

新版真机用例为 `integration_test/direct_web_verification_test.dart`，通过实际
`RoutedMiWebVerifier` / `DirectVerificationPage` / 原生内嵌 WebView 运行。
原始报告为 `build/verification/direct-web-verification-result.json`，失败列表为空。
回调使用本地测试凭据，未填写或提交用户账号与验证码；真实账号登录仍由用户亲自确认。

### 账号预填、多平台榜单与音箱对齐（2026-09-10）

用户授权把当前表单账号密码带入 App 内的小米验证页，并要求恢复其他平台榜单、统一布局、
整理设置及参考服务端的音箱播放实现。本轮仅修改 App，Server 保持原状。

- 账号密码通过 `MiWebLoginPrefill` 临时传入本次验证请求，使用原生参数传递到固定脚本；
  仅填写 `https://account.xiaomi.com` 主框架的 `/pass/serviceLogin`、`/fe/service/login`
  或原站实际使用的 `/fe/service/login/password`。
  兼容延迟挂载的表单，已有用户输入优先。预填完成、退出或取消释放引用；不保存密码、
  不勾选协议、不填写验证码、不点击登录，Cookie 与 STS 交接仍走既有认证事务。
- 榜单目录与 Server 的公开目录对齐：网易云、QQ、Apple、Spotify 公开榜和本机热播。
  网易榜只获取所需的 50 首；QQ 空榜时查询当前期号再试一次；Apple 使用官方公开 RSS；
  Spotify 只读取公开嵌入页面元数据，不把预览片段当作整曲、不读取 Server 账号凭据。
  公开榜缓存一天，刷新失败保留上次成功数据；热播按本机 30 天历史汇总。
- Apple/Spotify 整榜先匹配一首开播，再按榜单次序补充队列；替换、清空、停止、切模式和
  仓库销毁使旧任务失效。队列落盘事务内再次校验代数，防止迟到搜索污染新队列。
- 两种模式复用设置菜单与子页，摘要置于标签下方；大字、窄屏和宽屏双栏保留未保存输入。
  直连配置分为播放偏好、音箱播放及可展开的高级连接选项；账号经 ViewModel 摘要展示，
  补充兼容型号会校验、去重和大写归一，并实际参与音箱接口选择。
- 型号表改为 Server 的精确匹配规则，包含 LX06、L06A、L15A、L16A、L17A；
  播放负载包含对应 media，普通控制优先 `app_ios`，S12A 保留固件兼容请求。
  状态兼容 `info` 字符串/对象以及 `audio_id/global_id/id`；无效数据不会误判为探测成功。
  暂停超过 20 分钟重新解析播放地址，可定位的音箱恢复原进度；OH2/P 如实从头恢复。
  重复不变的进度不再不断推迟曲末时间，续播重新核实播放实例，原有超时不重发保护保留。

自动化：全仓 605 项通过、3 项商店专项跳过；商店专项单独运行 3 项通过、2 项普通模式
用例跳过。`flutter analyze --no-pub` 无问题，`dart format .` 检查 576 个文件无差异，
`git diff --check` 通过。普通 URL 恢复播放保留已学习的音箱播放标识，避免前台状态同步
误放弃控制；重新解析并完整播放时更新播放标识。

2026-09-10 02:18（Asia/Shanghai），`integration_test/direct_mode_polish_test.dart`
在 iOS 26.5 / iPhone 17 Pro Max 模拟器通过，两项原生集成测试覆盖：

- 真实小米原站在 App 内加载，并通过 DOM 验证临时账号密码预填；使用虚构凭据，没有提交
  登录、勾选协议或填写验证码。另以本地 HTML 验证延迟表单、保留手动编辑及外域不预填。
- 本地测试 Cookie 与 STS 回调在 App 内完成交接，退出、取消和挂载前取消后均清理验证状态。
  该回调验证使用受控数据，不代表真实账号登录成功。
- 网易、QQ、Apple Music、Spotify 代表榜的真实公开接口均返回 50 首，目录共 17 榜；
  QQ 筛选显示 3 榜。设置主页、直连配置和展开的高级音箱选项截图已检查，无布局溢出。

模拟器报告及截图位于 `build/verification/simulator/`；测试日志为
`build/verification/direct-mode-polish-simulator.log`，全仓测试及静态检查日志分别为
`build/verification/direct-mode-polish-tests.log`、`direct-mode-polish-analyze.log`。
实体 iPhone 17 Pro Max / iOS 27 在本轮启动时多次返回 `Locked`，02:21 查询仍要求解锁，
本轮真机交互验收未完成。前文 00:11 的真机结果属于上一版，不作为此次预填等新增行为的
验收证据。真实账号登录、真实音箱、后台/锁屏与系统挂起后的行为仍需实际设备验收。

2026-09-10 02:31，最新 `lib/main.dart` 的 iOS Release 正常包（36.1 MB）已恢复安装到
实体 iPhone，替换之前的验收包。增量构建遗留外层资源签名，使用既有开发身份保留标识、
entitlements 和 flags 重新签名后，`codesign --verify --deep --strict --verbose=2` 通过。
安装成功后立即启动仍被设备以 `Locked` 拒绝，因此仅记录构建、签名和安装成功，
不据此宣称正常版的真机页面验收通过。当前安装包为 `build/ios/iphoneos/Runner.app`，
构建日志、安装及启动结果分别见 `build/verification/direct-mode-polish-main-build.log`、
`build/verification/polish-main-install.json`、`build/verification/polish-main-launch.json`。
