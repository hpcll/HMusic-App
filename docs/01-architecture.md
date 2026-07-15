# 01 - Flutter 架构与工程结构

> 目标：用最少的基础设施完成“连接服务器 -> 登录 -> 搜索 -> 本机播放 -> 后台续播”纵切，
> 同时保留五平台扩展空间。
> 主架构已冻结为 **Feature-first MVVM**，详见 `decisions/ADR-0001-feature-first-mvvm.md`；
> 文件拆分、依赖和复用门禁见 `10-engineering-standards.md`。

## 1. 技术选型

| 领域 | 选型 | 边界 |
|---|---|---|
| UI 内容层 | Flutter / Material 基础组件 + 自有 token | 页面、列表、歌词、图表与业务状态 |
| iOS chrome | Swift/SwiftUI 原生桥 | iOS 27 液态玻璃顶栏、底栏、mini player、控制面板 |
| Android chrome | Flutter AdaptiveGlassSurface | 视觉同构，支持性能与无障碍降级 |
| 状态与依赖注入 | Riverpod | 页面只观察所需状态，不设全局万能 Store |
| 路由 | go_router | 登录重定向、底部导航、沉浸歌词页 |
| HTTP | Dio | 统一 base URL、Bearer、超时、错误和 401 拦截 |
| 模型 | `json_serializable` + 明确 DTO | 禁止页面直接读动态 Map |
| 凭据 | flutter_secure_storage | token 不进普通 preferences |
| 普通设置 | shared_preferences | server base、主题等非敏感配置 |
| 音频 | audio_service + just_audio + audio_session | 详见 08 |

具体包版本在生成工程时由当日 Flutter stable 解析并锁入 `pubspec.lock`；P0 不预写未经验证的版本号。

## 2. 目录结构

```text
HMusic-App/
├── lib/
│   ├── main.dart
│   ├── app/                  # MaterialApp、router、theme、应用级 provider
│   ├── core/
│   │   ├── config/           # ServerConfig、持久化与 URL 规则
│   │   ├── network/          # ApiClient、ApiError、auth interceptor
│   │   ├── models/           # 跨 feature 的 Track/Playback/Queue DTO
│   │   ├── audio/            # HMusicAudioHandler、同步协调器
│   │   └── platform_shell/   # Dart 侧 chrome 状态、命令和降级实现
│   └── features/
│       ├── connection/       # 服务端地址与探活
│       ├── auth/
│       ├── player/
│       ├── search/
│       ├── queue/
│       ├── playlists/
│       ├── charts/
│       ├── stats/
│       └── settings/
├── test/                     # 纯 Dart/Widget 测试
├── integration_test/         # 真 Server 契约和主链路
├── ios/Runner/               # Swift/SwiftUI NativeGlassShell 与 MethodChannel
├── android/                  # 平台配置；玻璃效果默认由 Flutter 实现
├── macos/ windows/ linux/
└── docs/
```

每个 feature 按需包含 `data/models/view_models/views/widgets`，严格执行
`View -> ViewModel -> Repository -> ApiClient/Storage`。不机械制造空目录，也不省略职责边界。
跨 feature 的 Track、PlaybackState、Queue 和 API 错误放 `core`；业务页面不相互 import。

## 3. 平台自适应 UI 边界

```text
Flutter App
  ├── Content Layer：页面、路由、业务状态、播放器协调、暖纸/墨色设计系统
  └── PlatformShellController
        ├── iOS 27+ -> Swift/SwiftUI NativeGlassShell
        ├── older iOS -> SwiftUI system material fallback
        └── Android/desktop -> Flutter AdaptiveGlassShell
```

iOS 原生层只接收最小展示状态：当前 tab、标题、mini player 元数据、播放状态、主题和无障碍偏好；
只回传 `selectTab/playPause/previous/next/openNowPlaying` 等用户意图。Swift 不持有 token、不调 API、
不直接操作队列，所有意图回到 Flutter 的 Router 或 PlaybackCoordinator。

桥接优先使用单一 MethodChannel + EventChannel（或等价 typed channel），禁止为每个控件建立独立通道。
Flutter 内容必须为原生顶栏/底栏预留由 Swift 回报的动态安全区，旋转、键盘、mini player 显隐时不能遮挡。

液态玻璃不是全局皮肤：内容卡片、曲目行、歌词、统计图表继续由 Flutter 绘制并保持 HMusic 品牌；
原生材质只承载导航、控制和临时浮层。iOS 27 API 不可用或“降低透明度”开启时必须自动回退。

## 4. 启动状态机

```text
启动
  -> 读取 server base
  -> 无地址：连接服务器页
  -> GET /system/info 探活与版本校验
  -> 读取 secure token，GET /auth/status
  -> initialized=false：创建管理员
  -> initialized=true + authenticated=false：登录
  -> authenticated=true：进入应用壳，拉 playback/queue
```

地址规范：仅接受 `http`/`https`，去掉尾部 `/`，拒绝 credentials/query/fragment；P0 不接受
带子路径部署。连接局域网 HTTP 时，平台放行规则见 06。

## 5. 网络层

- `ApiClient` 的 `baseUrl = <serverBase>/api/v1`，所有功能只能经此入口。
- 连接超时 5 秒、普通请求 15 秒；搜索/导入/音源测试可单独延长。
- 错误统一解析 `{error:{code,message,details}}` 为 `ApiError`。
- 任意 401：单飞清 token、停止本机音频、回登录页；避免多个请求重复弹窗。
- 日志不得打印 password、token、小米凭据、完整音频签名 URL。
- P0 前台每 3 秒刷新播放态、每 10 秒刷新非播放页 mini 状态；不依赖当前伪 SSE。

## 6. 播放数据流

远程音箱：UI 调 `/playback/*`，展示服务端状态，不启动本机播放器。

本机设备 `local-browser`：

1. UI 调 `/playback/play`，服务端选曲、记账并返回带 `streamUrl` 的 PlaybackState。
2. `PlaybackCoordinator` 把 URL host 重绑定到当前 server base，再交给 `AudioHandler`。
3. `AudioHandler` 播放并成为 position/duration/buffering 的事实源。
4. 协调器定时 `/local-report`；ended 由后台 handler 上报并装载返回的下一曲。
5. UI 的播放按钮和系统媒体按钮都调用同一个协调器，禁止各写一套时序。

URL 重绑定示例：已连接 `http://192.168.1.10:8090`，服务端返回
`http://127.0.0.1:8090/api/v1/proxy/audio/abc.sig`，客户端实际播放
`http://192.168.1.10:8090/api/v1/proxy/audio/abc.sig`。只保留返回 URL 的 path/query。

## 7. 状态与并发规则

- 搜索、歌单等普通列表用 AsyncValue 表达 loading/data/error。
- 播放命令串行化；同一时刻只允许一个 play/next/previous/ended 转换在途。
- seek 和音量允许节流，松手立即提交最终值。
- server base 改变时先停止音频、清 token 和业务缓存，再探活新服务端。
- P0 明确按“单个本机客户端控制全局 `local-browser`”设计；多客户端争用留待 Server 会话化。

## 8. 测试边界

- 单测：URL 规范化、DTO 解码、ApiError、播放状态归并、401 单飞。
- Widget：连接/首次设置/登录三态、底栏恒可见、沉浸歌词返回。
- 平台壳：Dart/Swift 消息契约、tab 与媒体意图、动态安全区、原生壳失效回退。
- 契约测试：对真实 HMusic-Server 覆盖 system/auth/search/play/local-report/queue。
- 真机：iOS 27 液态玻璃与旧 iOS 回退；Android 高/中/低画质；后台音频、中断和媒体控制。

## 实现状态

- [x] 架构定案
- [ ] Flutter 工程生成
- [ ] 核心 DTO 与 ApiClient
- [ ] AudioHandler 纵切
- [ ] iOS Swift/SwiftUI NativeGlassShell spike
- [ ] Android AdaptiveGlassSurface spike
- [ ] P0 集成测试
