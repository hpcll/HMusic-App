# 09 - Server/App 审计基线（2026-09-17）

> 审计对象：`HMusic-Server` 当前工作树（**v0.3.0**）与 `HMusic-App` 当前工作树（**v0.1.9**）。
> 方法：实跑两侧门禁 + 逐项核对路由注册、Zod schema、客户端仓库实现与路线图勾选。
> 历史基线：2026-07-12 的 P0 立项审计，逐项核对结果见 §3。
>
> **文档漂移提醒**：本文与 `docs/00` 曾长期停留在 7 月状态（“无代码 / 10 项测试”），
> 与代码严重脱节。本版按当前代码回填。凡**未在本轮复验**的条目都显式标注来源，
> 不要把路线图勾选当成本轮结论。

## 2026-09-18 接续复验

本轮仅修改 App（LX/Spotify/下载入口/纯播放器），Server 无代码改动。
以下新增结果不覆盖后文 09-17 历史审计，也不关闭真机与文件规模历史风险：

| 检查 | 本轮结果 |
|---|---|
| App 全量测试 | 至少一项与纯播放器入口裁剪追加后 657 通过 / 4 商店专项跳过 |
| StoreEdition 专项 | 5 通过 / 4 普通模式跳过 |
| Server 类型与测试 | typecheck 通过；22 文件 / 146 测试通过 |
| Android LX 原生测试 | API 36 ARM64 模拟器 3 项通过，含 64 MB 限制 |
| Android 原生音频链路 | LX → 代理 → AudioService/just_audio，暂停/seek/自动下一曲/单曲循环/切换停止通过 |

纯播放器不读小米凭据、固定本机目标、共享直连本地数据，Server 继续独立。
完整命令、静态/格式门禁与未验边界见 [本轮验收记录](reviews/2026-09-18-player-lx-spotify.md)。

## 1. 结论

P0 纵切（连接 → setup/login → 搜索 → 本机播放 → local-report → 后台下一曲）已交付并随
v0.1.9 发布，P0/P1/P2 的验收条目在路线图上全绿。当前阶段不是补 P0，而是三条线并行收口：

1. **P3 移动质量**——真机中断矩阵、锁屏长时、弱网恢复、性能基线。
2. **P5 分发合规**——签名公证、隐私政策、HTTPS 审核 Demo Server、内容权利审查。
3. **P7 直连模式**——代码全绿但真实小米账号与音箱仍待真机实测。

Server 侧主业务面稳定（18 个路由模块，146 项测试全过），**无阻塞客户端的契约缺口**。
仍有四项事实性风险保持开放：SSE 只发一帧、`streamUrl` 生成基址、`local-browser` 全局设备
语义、JWT 无过期。客户端对这四项都有确定的降级或处理策略，均不阻塞当前阶段。

App 侧唯一未过的门禁是文件规模：`mi_account_view_model.dart` 314 行，双超 `docs/10` 的
ViewModel（280）与任意文件（300）上限，需拆分或在文件头补拆分说明。其余各层均在限内。

## 2. 本轮验证基线（2026-09-17 实跑）

| 检查 | 命令 | 结果 |
|---|---|---|
| App 静态分析 | `flutter analyze --no-pub` | **No issues found** |
| App 全量测试 | `flutter test --no-pub` | **630 通过 / 3 跳过**（商店专项），All tests passed |
| Server 类型 | `npm run typecheck` | **通过** |
| Server 测试 | `npm test` | **22 文件 / 146 测试全过** |

> 环境注意：App 侧跑 `flutter test` 前必须 `unset HTTP_PROXY HTTPS_PROXY`（并设 `NO_PROXY=*`），
> 否则 Dart 的本地 WebSocket 会尝试走代理，全部测试文件报
> `Unable to connect to flutter_tester process`。这是环境问题，不要改仓库配置。
>
> 未纳入本轮：真机、后台音频、商店构建、GPU 帧时间基线。见 §5、§6。

规模事实：`lib/` 422 个 Dart 文件 / 36,422 行；`test` + `integration_test` 167 个文件 /
20,188 行；`ios/` 64 个 Swift 文件。

**文件规模门禁有一处违规**（`docs/10`：ViewModel 超 280 行、任意文件超 300 行必须拆分并说明）：

| 文件 | 行数 | 门禁 | 情况 |
|---|---|---|---|
| `features/settings/view_models/mi_account_view_model.dart` | **314** | ViewModel ≤280 / 任意文件 ≤300 | 双超，且文件头无拆分说明 |

其余各层均在限内：View 层最大恰好 220（`queue_page.dart`、`connection_page.dart`，等于上限未超），
第二大的 ViewModel 是 `charts_view_model.dart` 278 行。这是本轮唯一一处门禁未过，
7 月审计时该项为绿（当时最大 248 行），属其后新增功能的累积。

## 3. 历史 P0 阻塞项与风险：逐项核对

沿用 2026-07-12 基线的编号，便于追溯。**状态列已按本轮代码核对更新。**

结论：P0 立项时唯一的真阻塞项 S-P0-01 已关闭；S-P0-02/03 与 R-03/R-07 转为长期事实，
客户端各有降级策略，不再构成开工阻塞；其余风险项已随功能交付关闭。

| ID | 原事实 | 本轮核对结果 | 状态 |
|---|---|---|---|
| S-P0-01 | `/playback/play` strict schema 不接受 `queueIndex` | Server 已接受，重复歌曲队列回归测试覆盖 index 0/1；客户端队列点播直接发送 `queueIndex` | 已关闭 |
| S-P0-02 | `/playback/events` 写一帧后 `end()` | **事实未变**（`playback.routes.ts` 仍 `writeHead` → `write` → `end`）。客户端按“不依赖 SSE”实现，走 3s/10s 轮询 | 保持开放，不阻塞 |
| S-P0-03 | `streamUrl` 由 `HMUSIC_PUBLIC_BASE_URL` 生成，默认 `127.0.0.1` | **Server 侧未变**；客户端已统一按已连接 server base 重绑定 host/port，`stream_url_rebaser_test.dart` 覆盖（含裸主机名 → IPv4 解析，规避 AVFoundation -1008） | 客户端已解决 |
| R-01 | 重启恢复为 paused 且清空易逝 `streamUrl` | `playback.service.ts` 注释与实现一致（“streamUrl 是易逝的解析产物，不入快照”）；客户端冷启动展示恢复态、resume 重新解析续播 | 已关闭 |
| R-02 | downloads 已在 Server 后台执行 | 已是稳定契约；App 侧管理页已随 P2 交付（搜索页触发、3s 轮询、失败重试、删除） | 已关闭 |
| R-03 | `local-browser` 是服务端全局虚拟设备，无 client/session 隔离 | **事实未变**（`devices.service.ts` 中 `LOCAL_DEVICE_ID = "local-browser"` 全局单例）。客户端仍按“单活本机客户端”设计 | 保持开放，不阻塞 |
| R-04 | 音频代理 URL 带签名且可能过期 | 客户端已实现按当前曲目与位置自动恢复一次（60s 去抖），`stale_url_recovery_test` 全链路覆盖 | 已关闭 |
| R-05 | `/auth/status` 兼具初始化与 token 校验 | 未变；客户端先用 `/system/info` 探活再决定 setup/login | 已关闭 |
| R-06 | Server 常见部署是明文 LAN HTTP | Android cleartext、iOS Local Network/ATS 已于 2026-07-31 真机验收通过（来源：`docs/07`，本轮未复验） | 已关闭 |
| R-07 | JWT 未设置过期时间 | **事实未变**（`app.ts` 中 `register(jwt, { secret })`，无 `sign.expiresIn`）。客户端仍按 401 失效处理，token 存 secure storage | 保持开放，不阻塞 |

2026-07-12 版 §10 列的首个发布前置项——「Server 没有账户删除能力」——**已关闭**：
`DELETE /api/v1/auth/account` 已实现（`auth.routes.ts`），会联动清理 mi 账号、播放态、队列
和 Spotify 状态；App 侧安全区块已有红色入口 + 密码二次确认。

## 4. 稳定 API 面（2026-09-17 核对路由注册）

`src/app.ts` 共 18 处注册：`compat`（无前缀）+ 17 个 `/api/v1/*` 前缀模块。

- **公开**：`GET /system/info`、`GET /system/test-tone.wav`、`GET /system/app-config`、
  `GET /auth/status`、`POST /auth/setup`、`POST /auth/login`。
- **Bearer**：`system`(update)、`auth`、`config`、`devices`、`mi`、`sources`、`search`、
  `playback`、`proxy`、`queue`、`playlists`、`tracks`(lyrics)、`charts`、`spotify`、
  `stats`、`downloads`、`library`。
- **本机音频链路**：`POST /playback/play` 返回 `streamUrl` → 客户端重绑定 host →
  `POST /playback/local-report` 回写并在 `ended` 时推进队列 →
  `GET /proxy/audio/:token` 支持 Range 透传。
- **请求层门禁**：`app.ts` 在所有路由之前挂了老 App 版本门禁，自报版本低于
  `minSupportedAppVersion` 时直接拒绝；客户端另有 `/system/info` 的 `minAppVersion`
  全屏强升页（`core/upgrade/`）。
- **错误**：AppError / Zod / Fastify 统一归一到 `{error:{code,message,details}}`；
  凭据类失败保留 `@fastify/jwt` 原始 code（`FST_JWT_*`），不压成统一 `UNAUTHORIZED`。

仍**不作为依赖**：`compat` 路由、开发用 `/devices/mock`、一次性 `/playback/events`。

完整字段契约见 `docs/02`。注意 `docs/02` 的「上架相关 API 缺口」一节已过期
（账户删除已实现），其余章节仍有效。

## 5. 当前 App 侧差距

按 `docs/07` 勾选统计：**已完成 63 / 部分完成 13 / 未开始 18**（共 94 条）。
未开始条目集中在：

| 阶段 | 未开始条目 |
|---|---|
| P3 移动质量（7） | 中断矩阵双真机、锁屏 30 分钟与后台续播边界、弱网/离线/切 Wi-Fi/token 失效恢复、启动内存耗电音频基线、iOS Liquid Glass 与 Android 三档 blur 帧时间 GPU 基线、Reduce Motion/Transparency 逐项验收、Android 实体音量键遥控音箱 spike |
| P4 桌面原生（2） | 托盘/关窗驻留/窗口状态记忆；开机自启与外链打开 |
| P5 分发（5） | 签名公证与局域网权限说明；HTTPS 审核 Demo Server + 审核账号 + 测试音频 + Review Notes；隐私政策/支持 URL/App Privacy/Data Safety/SDK privacy manifest；内容权利审查与商店版 LX/下载边界；TestFlight/Google closed test 全过 |
| P6（2） | M3 语音接管 Server 侧 conversation 轮询服务与 App 侧开关 |
| P7（1） | 双真机前后台/锁屏/音箱验收；真实小米账号登录验收 |

**口径要求**：`docs/07` 中 2026-07-31 的真机验收结论是历史结果，不自动覆盖其后
（09-06 至 09-10）的 UI 与模式变更。P3 的复验门禁继续有效。直连模式当前的小米登录、
控制与状态测试**仍使用模拟传输**，不得据此宣称真实账号或音箱验收通过。

## 6. 当前阶段出口门禁

**已关闭**（本轮实跑或代码核对）：

- [x] App `flutter analyze` / `flutter test` 零错误（630 通过 / 3 跳过）
- [x] Server `npm run typecheck` / `npm test` 通过（22 文件 / 146 测试）
- [x] MVVM 依赖方向门禁：View 层全部 ≤220 行，无跨 feature 相互 import
- [ ] **文件规模门禁：`mi_account_view_model.dart` 314 行**（ViewModel 限 280、任意文件限 300），
      见 §2。需拆职责或在文件头补拆分说明
- [x] 401 单飞清会话并回登录页；错地址、离线、非 HMusic 服务都有确定状态
- [x] `streamUrl` 含 `127.0.0.1` 时按已连接 base 重绑定
- [x] 冷启动恢复态 + resume 重新解析续播
- [x] 账户删除（`DELETE /auth/account`）Server 与 App 双侧落地
- [x] ADR-0002 / ADR-0003 已冻结商店定位与首发边界

**未关闭**（需真机或商店流程，不能由代码审查替代）：

- [ ] P3 全部真机门禁（§5 表第一行）
- [ ] P4 桌面常驻与窗口状态
- [ ] P5 签名、隐私、审核环境与商店通道
- [ ] P7 真实小米账号与音箱实测
- [ ] Android 实体音量键遥控音箱 spike

## 7. 审计边界

- 本轮以 2026-09-17 两侧工作树为契约基线；并行发生的新提交需重新核对。
- §2 的四项门禁为**本轮实跑**；§3、§5、§6 中标注「来源：`docs/07`」的条目为
  **历史记录转述**，本轮未复验。
- 视觉像素级验收、桌面插件兼容性、应用商店签名属于后续阶段。
- 视觉与交互规格见 `docs/03`、`docs/04`、`docs/05`；平台原生能力见 `docs/06`；
  音频实现见 `docs/08`；直连模式见 `docs/14`。
