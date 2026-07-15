# 09 - P0 审计基线（2026-07-12）

> 审计对象：`HMusic-Server` 当前工作树，以及 `HMusic-App` 当前工作树。
> 方法：逐项核对 app 路由注册、Zod schema、共享 contracts、Web 实际调用和客户端文档。

## 1. 结论

HMusic-App 已生成 Flutter 工程，并完成连接、鉴权、搜索和本机播放基础模块。当前 P0 不是“继续规划”，
而是补齐播放器 UI、队列契约、平台玻璃壳和真机后台播放验证。

HMusic-Server 的主业务面足以支持客户端；原 `queueIndex` strict schema 阻塞已修复并有回归测试。
仍需显式降级/约束的风险主要集中在 SSE、LAN streamUrl、本机设备多端争用和商店合规。

## 2. P0 高优先级问题

| ID | 事实与证据 | 影响 | 关闭标准 |
|---|---|---|---|
| S-P0-01 | `/playback/play` 已接受 `queueIndex`；重复歌曲队列回归测试覆盖 index 0/1 | 已关闭 | 客户端队列点播直接发送 `queueIndex` |
| S-P0-02 | `/playback/events` 写入当前态后立即 `end()` | 不是持续 SSE，无法承担实时同步 | P0 文档/客户端只轮询；若保留端点，后续实现长连接、心跳和清理测试 |
| S-P0-03 | `streamUrl` 用 `HMUSIC_PUBLIC_BASE_URL` 生成，默认是 `127.0.0.1` | 局域网手机直接使用会访问自己，必定无声 | 客户端统一重绑定 host；Server 集成测试验证签名 path 经 LAN base 可播 |

S-P0-03 客户端已有无损兼容方案；S-P0-02 在 P0 只按“不依赖 SSE”处理。

## 3. 风险与冻结决策

| ID | 当前事实 | P0 决策 |
|---|---|---|
| R-01 | 播放态和队列已持久化；重启恢复为 paused 且清空易逝 streamUrl | 客户端冷启动展示恢复态；resume 返回值可能带重新解析的新 URL，必须重新装载 |
| R-02 | downloads 已进入 main，下载在 Server 后台执行并由客户端轮询 | API 记录进入稳定契约，但客户端管理页排到 P2，不扩大 P0 |
| R-03 | `local-browser` 是服务端全局虚拟设备，没有 client/session 隔离 | P0 只支持一个活跃本机客户端；设置页给出设备切换，不做多端仲裁 |
| R-04 | 音频代理 URL 带签名且无需 JWT，适配原生播放器；但 URL 可能过期 | 播放错误时按当前曲目和位置调用 `/playback/play` 重新解析，60 秒内最多自救一次 |
| R-05 | `/auth/status` 兼具初始化和 token 校验；`/system/info` 公开 | 先用 system/info 探活，再用 auth/status 决定 setup/login |
| R-06 | 服务端是明文 LAN HTTP 的常见部署 | Android cleartext、iOS Local Network/ATS 必须在 P0 真机验证，不把 HTTPS 当默认前提 |
| R-07 | JWT 当前未设置过期时间 | 客户端仍按 401 失效处理；token 存 secure storage，不打印日志 |

## 4. 已核对的稳定 API 面

P0 可依赖：

- 公开：`GET /system/info`、`GET /auth/status`、`POST /auth/setup`、`POST /auth/login`。
- Bearer：search、playback、queue、playlists、charts、stats、tracks/lyrics、devices、mi、config、sources、downloads。
- 本机音频：`POST /playback/play` 返回 `streamUrl`；`POST /playback/local-report` 回写并在 ended
  时推进队列；`GET /proxy/audio/:token` 支持透传 Range。
- 错误：AppError/Zod/Fastify 都归一到 `{error:{code,message,details}}`。

不作为 P0 依赖：compat 路由、开发用 `/devices/mock`、一次性 `/playback/events`、downloads 管理 UI。

## 5. HMusic-App 差距

| 能力 | 审计时状态 | P0 产出 |
|---|---|---|
| 技术栈 | Flutter 已定案但旧文档仍为 Tauri | 本轮统一为 Flutter |
| 工程 | 五平台 Flutter 工程已生成 | 继续维持 analyze/test 绿色 |
| 网络 | ApiClient、server base、Bearer、错误基础路径已实现 | 补齐 401 路由归并和契约测试 |
| 模型 | Track/Playback/Auth/ServerInfo 基础 DTO 已实现 | 补齐 Queue DTO 和未知枚举/字段测试 |
| 音频 | audio_service + just_audio AudioHandler 已建立 | 补齐播放器 UI、pause/seek、后台/锁屏真机验收 |
| 平台 UI | 无 Flutter/Swift 工程；现有规范只覆盖 Web 内容风格 | Flutter 内容层 + iOS 27 SwiftUI NativeGlassShell + Android 降级玻璃 spike |
| 工程组织 | 无代码，尚无架构约束 | Feature-first MVVM、细粒度文件、依赖准入和测试门禁 |
| 测试 | 无 | 单测、Widget、真实 Server 契约、双真机 |

## 6. P0 开工顺序

1. 保持 Server `queueIndex`、App `flutter analyze/test` 绿色，作为每轮修改前后门禁。
2. 补齐 player feature：mini player、pause/resume、seek、当前曲展示和错误状态。
3. 补齐 Queue DTO 和队列点播 `queueIndex` 客户端契约测试。
4. 完成 iOS NativeGlassShell 与 Android AdaptiveGlassSurface 最小 spike，冻结通道和回退策略。
5. 打通搜索 -> 本机 play/pause/seek/local-report/ended，验证 URL host 重绑定。
6. Android/iOS 真机完成前台、后台、锁屏最小闭环。

## 7. P0 出口门禁

- [x] Server `queueIndex` schema 与重复歌曲回归测试通过。
- [x] App `flutter analyze` 和 `flutter test` 零错误。
- [x] MVVM 依赖方向和文件规模检查通过；无巨型 View/ViewModel/Service（audio_handler 拆 projection 后 248 行）。
- [~] iOS 27 原生玻璃底栏/mini player 与 Flutter 双向 intent 打通；旧 iOS 可回退。
      （Dart PlatformShellController + MethodChannel 桥 + Swift 通道契约补齐，iOS 26.5 模拟器编译通过；
       SwiftUI 玻璃渲染与真机折射待设备门禁。）
- [ ] Android High/Medium/Off 三档玻璃壳布局一致，关闭 blur 后功能完整。
- [x] 错地址、离线、非 HMusic 服务、401 都有确定状态且不会卡启动（401 单飞 SessionController + 回登录页）。
- [ ] 首次 setup 与已有账号 login 均可进入应用壳。
- [ ] 搜索点播后 Android/iOS 本机出声，进度、暂停、seek 正常。
- [ ] 锁屏/后台播完能通过 local-report 自动进入下一曲。
- [ ] 返回 URL 含 `127.0.0.1` 时，客户端仍从已连接的 LAN host 成功拉流。
- [ ] 日志、错误页和持久化中无明文 password/token。
- [ ] Server 恢复为 paused 且 streamUrl 为空时，resume 能重新装载 URL 并续播。
- [x] App Store 首发范围、审核 Demo Server、公网 HTTPS/LAN HTTP 策略已有书面决策（ADR-0003 已冻结）。

## 8. 审计边界

本轮以审计结束时的 Server 当前工作树为契约基线；并行发生的新提交需重新核对。
视觉像素级验收、桌面插件兼容性、应用商店签名属于后续阶段。

## 9. 基线验证

在当前 HMusic-Server 工作树执行：

- `npm run typecheck`：通过。
- `npm test`：4 个测试文件、8 个测试全部通过。
- `npx vitest run "test/integration/api-contract.test.ts"`：通过，覆盖 `/playback/play`
  携带 `queueIndex` 的重复歌曲队列回归。
- `flutter analyze`：通过。
- `flutter test`：通过，10 个测试全部通过。

测试输出另有 Fastify `FSTDEP022`：`maxParamLength` 顶层配置将在 Fastify 6 移除，应迁移到
`routerOptions`，但它不阻塞 P0。现有验收仍未覆盖持续 SSE、完整队列 UI、downloads 状态流、
双真机后台播放和服务重启恢复，这些缺口已进入 P0/P2 门禁。

## 10. 发布前置审计

完整要求见 `11-release-compliance.md`。以下事项虽然不阻塞本地开发，但会改变产品/API，必须提前：

- App 内允许 setup 创建管理员，而 Server 没有账户删除能力；P2 前需 ADR 和 Server API。
- 家庭 LAN Server 无法供 App Review 访问；P0 冻结 HTTPS Demo Server 方案。
- LX、第三方音源和下载涉及内容权利与商店审核风险；P2 前冻结商店版边界。
- 任意公网 HTTP 不符合推荐安全姿态；App Store 构建仅允许本地地址 HTTP，公网必须 HTTPS。
- Background Audio 只用于手机本机播放，远程音箱模式禁止用静音音频保活。
- 中国大陆发布区域需要备案、内容权利和相关资质单独评估，不能默认勾选。
