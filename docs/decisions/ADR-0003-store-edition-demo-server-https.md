# ADR-0003 - 商店首发功能边界、Demo Server 与 HTTPS/LAN HTTP 策略

- 状态：Accepted / Frozen
- 日期：2026-07-13
- 决策者：项目所有者
- 关联：ADR-0002（产品定位）、`docs/09-p0-audit.md` §10、`docs/11-release-compliance.md`

## 背景

P0 门禁（docs/09 §7）与发布合规（docs/11）都要求在正式提审前冻结三件事：App Store 首发功能边界、
审核 Demo Server 方案、公网 HTTPS / LAN HTTP 策略。这三项会反向影响 Server API 和客户端编译配置，
不能拖到 P5。ADR-0002 已定位 HMusic 为自托管个人音乐库客户端；本 ADR 把该定位落成可编译的
`StoreEdition` 边界和审核/网络硬规则。

## 决策

### 1. StoreEdition 编译配置边界

商店版（`HMUSIC_STORE_EDITION=true`）与 Server Web/桌面直发版的功能差异由**编译期常量**决定，
不通过审核账号、地区或远程开关切换。已存在 `lib/core/config/build_edition.dart` 的
`BuildEdition.isStore`；客户端按它裁剪入口，不得用运行时检测伪装。

| 功能 | App Store 版（isStore=true） | 直发版 |
|---|---|---|
| 自托管 Server 连接、本机/后台/锁屏播放 | 保留 | 保留 |
| 队列、歌单、歌词、统计、设备遥控 | 保留 | 保留 |
| LX JavaScript 编辑/导入/测试 UI | **不放入** | 可保留，需权利与安全评估 |
| 服务端下载管理 UI | **不放入（P2 也不进商店版）** | 可保留，需权利评估 |
| 第三方平台名称/解析/下载的元数据宣传 | **不出现** | 不作产品宣传 |

LX 脚本和下载能力在 Server 侧仍可存在；商店版客户端只是不暴露管理入口，且不在商店元数据里宣传。
这与 ADR-0002 §「功能发行边界」一致：差异必须是公开的编译配置，不是审核后远程开启的隐藏功能集。

### 2. 审核 Demo Server 方案

- 提供一台开发者控制、公网可达、证书有效的 **HTTPS Demo Server**，专门供 App Review 使用，
  不与任何真实用户的 NAS/家庭 Server 共用。
- Demo Server 提前 `initialized`，审核账号为专用管理员，避免审核员走 setup 破坏环境。
- 仅承载**有授权或公版**测试音频与歌词；禁止暴露真实小米账号、家庭设备、私人播放历史或生产密钥。
- Review Notes 必须写清：Server 地址、审核账号密码、搜索→播放→暂停/seek→队列→歌词→后台播放的
  可复现步骤，以及为什么需要 Local Network 权限（即便审核走公网 HTTPS，仍要解释用户侧 LAN 场景）。
- Demo Server 至少保留到版本通过审核并稳定发布后一段时间；审核环境宕机等于提审失败。
- 客户端不对审核账号做任何特殊分支；Demo Server 行为与普通用户连接的 Server 一致。

### 3. 公网 HTTPS / LAN HTTP 策略

地址规范已在 `lib/core/config/server_address_policy.dart` 实现，本 ADR 冻结其规则来源：

- 仅接受 `http`/`https`，去尾斜杠，拒绝 credentials、query、fragment 和非空子路径。
- **本地范围允许 HTTP**：RFC1918、link-local、loopback、`localhost`、`.local`。本地 HTTP 时
  UI 提示「仅适合可信局域网」。
- **公网强制 HTTPS**：商店版（`isStore=true`）下，非本地 host 用 HTTP 直接被
  `ServerAddressException('公网服务器必须使用 HTTPS')` 拒绝；非商店版允许但不推荐。
- **不提供「忽略证书错误」开关**：自签证书推荐用户部署受信任证书或退回局域网 HTTP，
  禁止 `NSAllowsArbitraryLoads=true` 作为长期方案。
- iOS ATS：保留 `NSAllowsLocalNetworking=true`，不放开全局任意加载；公网 HTTPS 由系统 ATS 校验。
- Android：保留 `usesCleartextTraffic=true` 以支持 LAN HTTP；商店审核说明里明确仅本地明文用途。
- IPv6/NAT64、蜂窝切 Wi-Fi、Server 离线和证书错误在提审前必须真机过一遍。

`ServerAddressPolicy._isLocal` 是本策略的唯一判定点；新增 host 形态必须改这里并补单测，
不允许在页面或 Repository 里散落 `Platform.isIOS` / host 字符串判断。

### 4. 账户删除前置

STORE-02 不在本 ADR 关闭——账户删除语义需独立 Server ADR 与 API。但本 ADR 冻结前置约束：
App 内允许 setup 创建管理员，就**必须**提供 App 内发起删除；删除需密码复验、影响说明和二次确认，
且必须是删除账户及关联数据，不只是退出登录。在 Server 删除 API 落地前，商店版不提审。

## 理由

- 编译期 `StoreEdition` 比「远程开关」更能通过审核：Apple 明确反对审核后切换功能集。
- 公网 HTTPS + 本地 HTTP 受限是 ATS 与 Google Play cleartext 政策都能接受的最小姿态，
  既满足家庭 LAN 常见部署，又不给公网明文留口子。
- Demo Server 是 App Review 可访问性的唯一可靠路径；审核员不会与用户 Server 同 Wi-Fi。
- 把判定收敛到 `ServerAddressPolicy` 单点，避免五平台各自写 host 判断导致规则漂移。

## 后果

- `BuildEdition.isStore` 成为客户端裁剪 LX/下载入口的唯一开关；新增上述入口必须先过它。
- `ServerAddressPolicy` 规则变更需同步本 ADR 与 docs/11，并补 `server_address_policy_test.dart`。
- 在 Server 账户删除 API 与独立 ADR 落地前，P5 提审门禁无法关闭（STORE-02 保持开放）。
- 中国大陆 storefront 是否首发由项目所有者单独决策，本 ADR 不默认勾选。

## 非目标

- 不在此定义 Demo Server 的具体部署拓扑与运维（属发布工程，见 docs/11 §13）。
- 不在此定义账户删除 API 形状（属后续 Server ADR）。
- 不改变 LX/下载在 Server 侧的存在方式；只约束商店版客户端入口与元数据宣传。
