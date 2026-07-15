# 10 - 工程与代码组织规范

> 本规范是代码审查门禁。架构采用 **Feature-first MVVM**，已由
> `decisions/ADR-0001-feature-first-mvvm.md` 冻结；任何 AI 或开发者不得自行更换为 MVC、BLoC、
> Clean Architecture 全家桶或其他模式。

## 1. MVVM 职责

```text
View -> ViewModel -> Repository -> ApiClient / Storage / Platform Adapter
                     |
                     -> Domain service（只有真实跨页面规则时才存在）
```

### View

- Flutter Widget、布局、动画、语义和用户输入。
- 只读取 ViewState、发送 intent，不直接请求 API、读写存储或调用 platform channel。
- 不放业务判断；简单显示判断如 loading/empty/error 可以留在 View。
- Page 只负责页面编排，大块 UI 拆成同 feature 的 widgets。

### ViewModel

- 一个 ViewModel 对应一个页面或一个明确可复用交互单元。
- 持有不可变 ViewState，处理 intent、校验、并发、错误映射和 Repository 调用。
- 禁止依赖 `BuildContext`、Navigator、具体 Widget、Swift/Kotlin 类型。
- 导航通过明确的 navigation event 或 Router abstraction，不在 ViewModel 中拼页面。
- 禁止出现掌管整个 App 的 `AppViewModel` 或万能 Store。

### Model / Repository

- DTO 负责 JSON；领域模型负责客户端需要的稳定语义，两者只有确有差异时才分开。
- Repository 隐藏 API、缓存和存储细节，向 ViewModel 返回 typed result/model。
- Repository 不 import presentation；feature 之间不得调用对方 ViewModel。
- ApiClient、SecureStorage、Preferences、PlatformChannel 都通过小接口注入。

### Coordinator / Service

- 只用于真实跨页面、跨生命周期流程，例如 PlaybackCoordinator、AuthSession、AudioHandler。
- 不把普通 CRUD 包成 UseCase；单纯转发一层没有价值。
- Coordinator 不渲染 UI，ViewModel 不复制 Coordinator 的状态机。

## 2. Feature-first 目录

```text
lib/features/search/
├── data/
│   ├── search_repository.dart
│   └── search_repository_impl.dart
├── models/
│   ├── search_result.dart
│   └── search_view_state.dart
├── view_models/
│   └── search_view_model.dart
├── views/
│   └── search_page.dart
└── widgets/
    ├── search_input.dart
    ├── search_result_list.dart
    └── track_result_tile.dart
```

- 目录按业务 feature 组织，不建立横跨全项目的 `screens/`、`controllers/`、`widgets/` 大仓库。
- `core/` 只放真正跨 feature 的基础能力：network、audio、config、models、platform_shell、theme。
- `shared/widgets/` 仅放至少两个 feature 实际复用的视觉原子；未复用前留在原 feature。
- core 不依赖 feature；feature 不依赖另一个 feature 的 views/view_models/widgets。
- 公共业务流程通过 core coordinator 或小接口共享，不通过跨 feature import 绕层。

## 3. 文件与函数大小门禁

目标是高内聚的小文件，不是为了数字制造几十个空壳文件。

| 类型 | 目标 | 审查硬门槛 |
|---|---:|---:|
| Page/View | 80-180 行 | 超过 220 行必须拆分 |
| ViewModel | 100-220 行 | 超过 280 行必须拆职责 |
| 可复用 Widget | 40-120 行 | 超过 180 行必须拆子组件 |
| Repository/Service | 80-220 行 | 超过 280 行必须拆接口或流程 |
| 普通 Dart/Swift 文件 | 60-240 行 | 超过 300 行必须说明并拆分 |
| 方法/函数 | 5-30 行 | 超过 50 行必须提取步骤 |
| Widget `build` | 20-60 行 | 超过 80 行必须拆 Widget |

豁免：生成文件、纯常量映射、大型测试数据。豁免原因必须显而易见，不能用“以后再拆”过关。

拆分触发条件：

- 一个文件出现两个以上独立职责。
- 构造参数或 provider 依赖不断增长。
- 同一段 UI/逻辑第二次出现。
- 测试只能通过大量无关 mock 才能创建目标对象。
- 修改一个页面经常触碰不相关功能。

禁止文件名：`utils.dart`、`helpers.dart`、`common.dart`、`misc.dart`、`base_manager.dart`。
文件必须以具体职责命名，例如 `stream_url_rebaser.dart`、`auth_token_store.dart`。

## 4. 复用规则

复用优先级：

1. Dart/Flutter/Swift 标准能力。
2. 仓库现有组件、服务或模型。
3. 维护良好的成熟开源包。
4. 项目内最小专用实现。

- 第二次出现相同业务规则时立即评估复用；第三次出现前必须完成抽取或写明不抽取原因。
- 复用的是稳定语义，不是仅仅长得像的代码。两个组件只有颜色相同，不值得造万能组件。
- 禁止巨型 `BasePage`、`BaseViewModel`、`CommonWidget` 和接受几十个参数的“万能复用”。
- 组合优先于继承；小接口优先于抽象基类。
- 平台差异通过 interface + adapter 隔离，不在页面里散落 `Platform.isIOS`。

## 5. 禁止重复造轮子

以下能力优先使用已选或经审核的成熟方案，除非 spike 证明不能满足需求：

| 能力 | 默认方案 |
|---|---|
| 状态/DI | Riverpod |
| 路由 | go_router |
| HTTP/拦截器 | Dio |
| JSON | json_serializable |
| 安全存储 | flutter_secure_storage |
| 普通设置 | shared_preferences |
| 后台音频 | audio_service + just_audio + audio_session |
| iOS 液态玻璃 | iOS 27 公开系统 API + Swift/SwiftUI |
| 二维码 | 维护良好的本地 Flutter QR 包 |
| 图表 | 维护良好的 Flutter 图表包；仅品牌特有绘制可用 CustomPainter |

禁止自行实现通用路由器、HTTP 客户端、状态框架、JSON 生成器、安全存储、音频引擎、二维码编码器、
图表坐标轴/手势系统。确需自研时必须新增 ADR，记录现有方案为何失败、维护成本和退出策略。

第三方依赖准入必须检查：

- 许可证允许项目使用。
- 最近维护状态、issue 响应和 release 质量可接受。
- 覆盖目标平台，尤其 Android/iOS 真机。
- 不要求宽泛危险权限，不偷偷上传数据。
- 包体、启动、GPU/CPU 和传递依赖成本合理。
- 能被接口包裹，未来替换不会渗透所有页面。

## 6. 状态和错误模型

- 每个页面定义明确、不可变的 `XxxViewState`，不暴露可随意修改的 Map。
- loading、refreshing、empty、data、recoverable error、fatal error 必须能区分。
- ViewModel 对同类请求做 single-flight/cancel/debounce，不让旧响应覆盖新状态。
- API 错误在 Repository/ApiClient 转成 typed failure；View 不解析 HTTP status 或 JSON。
- 播放状态只由 PlaybackCoordinator/AudioHandler 汇总，页面不得自建播放 Timer 或队列副本。

## 7. 测试要求

- ViewModel：纯 Dart 单测覆盖成功、空态、错误、重试、并发和 dispose。
- Repository：mock ApiClient，验证 DTO/错误映射；关键 API 另做真实 Server 契约测试。
- View：Widget test 验证状态渲染、intent 和无障碍，不在 Widget test 重测网络逻辑。
- 共享 Widget：至少覆盖长文本、窄屏、深浅色和禁用态。
- 修复 bug 时先补能复现问题的最小测试。

## 8. 架构变更控制

Feature-first MVVM 是冻结决策。以下操作必须先新增 ADR 并获得用户明确确认：

- 改用 MVC、BLoC、Redux、Clean Architecture 或其他主架构。
- 更换 Riverpod、go_router、Dio、audio_service/just_audio 等核心基础设施。
- 改变 View -> ViewModel -> Repository 的依赖方向。
- 让 Swift/Kotlin 层开始持有业务状态或访问 HMusic-Server。

普通重构、文件拆分、接口收窄不属于架构变更，但必须保持行为与测试通过。

## 9. Code Review 检查表

- [ ] 文件、类、函数没有超过门槛；超限内容已拆分
- [ ] View 无 API/存储/platform channel 调用
- [ ] ViewModel 无 BuildContext/Widget 依赖
- [ ] feature 没有越层或依赖其他 feature 的 presentation
- [ ] 没有复制已有组件、模型、错误处理或播放逻辑
- [ ] 新依赖经过准入检查，没有可避免的自研轮子
- [ ] 状态、错误和并发路径有测试
- [ ] 文档与路线图已同步
