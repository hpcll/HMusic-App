# 11 - App Store / Google Play 上架与合规

> 本文是发布设计约束，不构成法律意见。Apple/Google 政策和 SDK 截止日期会变化，每次提交前必须
> 使用当期官方指南复核。不能把上架理解为“最后签个名”，其中多项要求会反向影响 Server API 和产品功能。

## 1. 推荐首发定位

HMusic App 定位为：**连接用户 NAS/家庭服务器上的 HMusic-Server 的个人音乐库播放器与家庭音箱控制器**。

完整的商店文案、审核说明和发行边界冻结在 `decisions/ADR-0002-app-store-positioning.md`。

推荐首发边界：

- App 不内置音乐、音源脚本、第三方账号或平台密钥。
- App 不直接读取 NAS 协议；准确说法是“播放运行在 NAS/家庭服务器上的 HMusic Server 音乐库”。
- App 不执行从 Server 下载的 JavaScript、插件或其他可执行代码。
- App 不销售数字内容或会员，不放外部购买引导；未来商业化单独评估 IAP。
- 审核环境使用开发者控制的 HTTPS Demo Server 和明确授权/公版测试音频。
- LAN HTTP 只允许私有地址、link-local、`.local` 等本地范围；公网地址必须 HTTPS。
- App Store 元数据不宣传“破解、免费下载付费音乐、绕过平台限制”等高风险能力。
- LX 插件编辑和 Server 下载功能必须在权利审查后决定是否进入商店版本；不得通过审核后远程隐藏/开启。

中国大陆 storefront 是否首发需要单独决策。若无法准备 ICP/适用备案及音乐内容相关资质，建议首版
暂不选择中国大陆销售区域，而不是带着不确定性提交。

## 2. 当前上架阻塞项

| ID | 问题 | 当前状态 | 关闭标准 |
|---|---|---|---|
| STORE-01 | 审核员无法访问用户家庭 LAN Server | 无公开审核环境 | 提供稳定 HTTPS Demo Server、地址、账号、测试曲目和 Review Notes |
| STORE-02 | App 内可创建管理员，但 Server 无删除账户 API | 仅 setup/login/password | 设计并实现账户删除；App 内可完成，不只提供邮件入口 |
| STORE-03 | 第三方音源、LX 插件、下载可能涉及内容权利 | 无权利说明/商店版边界 | 完成法律/权利审查，冻结商店版功能和元数据表述 |
| STORE-04 | 用户可填任意 HTTP 地址 | 当前设计偏 LAN HTTP | 公网强制 HTTPS；仅本地地址允许 HTTP；禁止忽略证书错误 |
| STORE-05 | 后台音频 entitlement 容易被质疑滥用 | 尚无 App 工程 | 只在本机真实播放时启用；远程音箱模式不保活静音音频 |
| STORE-06 | 隐私政策与 App Privacy/Data Safety 未定义 | 无发布文档 | 建立隐私数据清单、政策 URL、删除流程和商店问卷答案 |

STORE-01/02/03/04 必须在正式提审前关闭；其中 02/04 会影响客户端和 Server 设计，不能拖到 P5。

## 3. 审核可访问性

App Review 不能依赖审核员与 HMusic-Server 在同一 Wi-Fi。必须准备：

- 公开可达、证书有效、稳定运行的 HTTPS Demo Server。
- 专用审核账号，避免与真实用户数据混用。
- 至少包含搜索、播放、队列、歌词的可验证数据；使用有授权或公版音频。
- 若首次启动存在 setup 流程，审核环境应提前 initialized，避免审核员创建管理员破坏环境。
- Review Notes 写清 Server 地址、账号密码、测试步骤、后台播放操作和为什么需要本地网络权限。
- Demo Server 禁止暴露小米真实账号、家庭设备、私人播放历史或生产密钥。
- 审核环境应至少保留到版本通过审核并稳定发布后一段时间。

不得检测审核账号后切换成与普通用户不同的隐藏功能集。商店构建可有明确、公开的能力边界，但不能
用远程开关欺骗审核。

## 4. 账户、登录与删除

- HMusic 登录是用户自有 Server 的管理员账户，不是开发者运营的中心云账号；Review Notes 要解释。
- 当前没有第三方社交登录，因此通常不因登录本身要求 Sign in with Apple；未来加入 Google/微信等
  第三方主登录时，必须重新评估 Apple 登录要求。
- 只要 App 内允许创建账户，就应提供 App 内发起删除账户的能力。
- 删除应删除账户本身及与账户直接关联的数据，而不是只退出登录或停用。
- HMusic 是单管理员自托管系统，删除语义必须先设计：仅删除管理员、清空所有数据、还是让 Server
  回到未初始化状态。该操作需要密码复验、明确影响说明和二次确认。
- 删除 API 必须具备 CSRF/鉴权保护、审计日志脱敏和不可误触测试。

建议新增独立 Server ADR 后再定义接口，不能在客户端先假设 `DELETE /auth/account` 的具体行为。

## 5. 内容权利与音乐来源

这是 HMusic 最大的审核风险：

- 搜索/解析 QQ、网易云、酷我等平台内容，不等于拥有分发或下载权。
- “服务端下载”“解析付费音源”“导入第三方脚本”可能被理解为绕过平台限制或促进侵权。
- App 必须能证明其有权展示、播放和允许下载的示例内容。
- 封面、歌词、歌名等元数据也可能受权利或平台条款约束。
- 商店截图和宣传文案不要展示未授权明星封面、平台商标或暗示免费获取付费内容。

商店版本必须在以下方案中明确选择一个，不能模糊处理：

1. 仅连接用户自有/合法内容库，第三方解析和下载不进入商店客户端。
2. 获得相关平台授权并保留证明。
3. 只作为遥控和个人使用工具，但仍需法律评估其搜索/解析/下载流程是否合规。

技术上 LX JavaScript 在 Server 执行，不在 iOS 执行；客户端只上传文本和显示状态。实现必须保持
这个边界，禁止在 Flutter、WebView、JavaScriptCore 或 Swift 中执行 Server 下发代码。提审说明可
解释这一点，但它不能替代内容权利证明。

## 6. 隐私与数据清单

提审前建立数据流表，至少覆盖：

| 数据 | 存储/接收方 | 是否离开设备 | 要求 |
|---|---|---|---|
| HMusic 用户名/token | Keychain + 用户 Server | 是 | 安全存储、TLS/本地网、删除流程 |
| Server 地址 | 本地 preferences | 连接时发送 | 不作为开发者跟踪标识 |
| 小米账号/验证码/会话 | 用户 Server、Xiaomi | 是 | 敏感凭据不进客户端日志/分析 |
| 搜索词、播放历史 | 用户 Server、音源上游 | 是 | 隐私政策说明实际接收方 |
| 封面/歌词/音频请求 | CDN/用户 Server | 是 | 不附带无关设备标识 |
| 崩溃/分析数据 | 尚未决定 | 可能 | 默认不接入；接入前单独同意与披露 |

- 如果开发者不收集数据，而数据只在用户设备、用户 Server 和用户选择的第三方之间流转，商店问卷
  仍需按 Apple/Google 当期定义如实回答，不能简单写“完全无数据”。
- 提供公开可访问的隐私政策 URL 和支持 URL。
- 不做广告跟踪、不接广告 SDK、不建立跨 App 标识；没有跟踪就不请求 ATT。
- 检查所有 Flutter/iOS 第三方 SDK 的 privacy manifest、Required Reason API 和数据声明。
- release 日志禁止记录 token、密码、验证码、小米 cookie、完整签名音频 URL 和私人播放历史。

## 7. 网络、ATS 与本地网络

- iOS 提供清晰的 `NSLocalNetworkUsageDescription`，说明用于连接用户自己的 HMusic-Server/音箱。
- 不申请 Bonjour 权限，除非真正实现自动发现；申请时只声明实际使用的 service type。
- 禁止 `NSAllowsArbitraryLoads=true` 作为长期方案。
- 地址策略：
  - RFC1918、link-local、localhost、`.local`：允许 HTTP，并显示“仅适合可信局域网”的说明。
  - 公网域名/IP：必须 HTTPS 且证书有效。
  - 自签证书：不提供“忽略证书错误”开关；推荐用户部署受信任证书或仅用局域网 HTTP。
- URL 解析支持域名、IPv4 和带方括号的 IPv6；禁止 credentials、query、fragment 和路径注入。
- 审核与发布前验证 IPv6/NAT64、蜂窝网络切 Wi-Fi、Server 离线和证书错误。

## 8. 后台音频与系统权限

- Background Audio 只服务于手机本机真实播放。
- 选择小米音箱远程播放时，App 不应播放静音音频或维持无意义 AudioSession 来保活。
- 停止播放后及时释放播放器、前台服务和音频会话。
- Review Notes 给出：开始播放 -> 回桌面 -> 锁屏 -> 控制/自动下一曲的完整复现步骤。
- Android 前台服务声明必须与 media playback 实际用途一致，并完成 Play Console 对应声明。
- 不申请麦克风、相机、通讯录、位置等未实际使用权限。展示小米登录二维码不需要相机权限。

## 9. 付费、外链与商业化

- 当前免费客户端、用户自建 Server、不销售数字功能：无需 IAP。
- 未来若销售会员、云 Server、音源、数字内容或客户端高级功能，必须在设计前评估 Apple IAP 和
  Google Play Billing；不能先接网页支付再补合规。
- 不在 App 内放“去官网购买会员”等按钮，除非当期政策和对应 storefront 明确允许。
- 购买实体硬件、捐赠、企业服务等属于不同规则，商业化时新增 ADR。

## 10. 商店素材与法律信息

- 固定 Bundle ID、App 名称、SKU、版本号和 build number 规则。
- 准备 App Icon、启动画面、iPhone/iPad 截图、预览视频、简短/完整描述、关键词和更新说明。
- 截图必须来自真实 App，不使用不存在的功能或误导性设备框。
- 准备隐私政策、服务条款、支持页面、支持邮箱和版权声明。
- 确认 HMusic 名称、图标、字体、测试封面、歌词和所有商店素材的授权。
- 完成年龄分级和内容权利问卷；音乐内容与用户可访问来源必须如实说明。
- 按实际加密使用回答 Export Compliance；仅使用系统 TLS/Keychain 时仍要按当期表单判断豁免。
- 每次提审使用 Apple 要求的当前 Xcode/iOS SDK 和 Google 要求的 target SDK。

## 11. 中国大陆发布

若选择中国大陆 App Store/应用市场，需要提前核对：

- App 备案/ICP 等当期要求。
- 音乐播放、聚合搜索、歌词、下载可能涉及的网络文化、视听或版权资质。
- 小米、QQ音乐、网易云、酷我等品牌和接口使用授权。
- 隐私政策、个人信息处理、跨境传输和第三方 SDK 清单。

在资质和内容权利没有明确结论前，不默认勾选中国大陆 storefront。本项必须由项目所有者做最终
发布区域决策，技术团队不能自行假设“个人工具所以不需要”。

## 12. Google Play 补充

- 发布 AAB，启用 Play App Signing，管理 upload key 和恢复材料。
- 满足当期 target API level、Data Safety、隐私政策、账号删除和测试账号要求。
- 申报媒体播放 Foreground Service 类型及其核心用途。
- 处理 Android 13+ 通知权限，但拒绝通知权限不能阻止前台使用。
- 若使用 closed testing/生产访问门槛，提前准备测试人员与周期。
- 同样执行内容权利、远程代码、HTTP 安全和审核 Demo Server 门禁。
- **App 内自更新只属于直装渠道**：GitHub Release / 网盘分发的 Android 包在
  「设置 → 关于与更新」里下载 APK 并交系统安装器，因此主 manifest 声明了
  `REQUEST_INSTALL_PACKAGES`、并带一个 `${applicationId}.updates` FileProvider。
  上架 Play 的构建必须去掉这条权限与该入口（Play 禁止应用自行分发/安装 APK）：
  Dart 侧已由 `BuildEdition.isStore` 关掉入口（见
  `features/settings/view_models/app_download_view_model.dart` 的
  `canSelfInstallApp`），但**权限仍在 manifest 里**，上架前需要一个去掉它的
  manifest 变体（product flavor 或 `tools:node="remove"` 覆盖），否则会被
  Data Safety/权限申报卡住。

## 13. 发布工程与密钥

- CI 使用 App Store Connect API Key/签名证书的最小权限 secret，不提交 `.p8`、证书或密码。
- 区分 dev/staging/review/prod 配置，但功能边界公开一致；Review 环境只替换 Server 地址和数据。
- iOS 只能通过 App Store/TestFlight 更新二进制，禁止自更新或下载执行新代码。
- release 构建关闭调试入口、DevTools 和详细网络日志。
- TestFlight 先完成内部测试、外部测试、崩溃和后台音频观察，再送正式审核。
- 保存每次提交的版本、commit、依赖锁、隐私问卷、Review Notes 和审核反馈记录。

## 14. 提审检查表

- [ ] 内容权利和商店版功能范围已由项目所有者确认
- [ ] HTTPS Demo Server、审核账号、公版测试音频可用
- [ ] App 内账户删除和 Server 删除语义完成
- [ ] 公网强制 HTTPS，本地 HTTP 范围受限，无证书绕过
- [ ] 隐私政策、支持 URL、App Privacy/Data Safety 已核对
- [ ] 第三方 SDK privacy manifest/权限/许可证已审计
- [ ] 后台音频只在本机播放时运行，Review Notes 可复现
- [ ] 无下载执行代码，无隐藏审核功能，无外部数字购买绕过
- [ ] 图标、截图、描述、年龄分级、内容权利、出口合规完成
- [ ] iOS 27/旧 iOS/Android 真机回归，TestFlight/closed test 通过
- [ ] 签名密钥和 CI secrets 有备份、轮换和最小权限
- [ ] 发布区域，尤其中国大陆，已经明确决定
