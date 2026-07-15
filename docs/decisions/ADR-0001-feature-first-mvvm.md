# ADR-0001 - 冻结 Feature-first MVVM

- 状态：Accepted / Frozen
- 日期：2026-07-11
- 决策者：项目所有者

## 背景

HMusic App 同时包含普通 CRUD 页面、实时播放状态、后台 AudioHandler、Flutter/Swift 平台壳和
五平台适配。项目要求文件小、职责清晰、可复用，并避免 Controller/Store 随功能增长成为巨型对象。

## 决策

采用 **Feature-first MVVM**：

- 先按 connection/auth/player/search/queue 等 feature 划分目录。
- View 只负责渲染和 intent。
- ViewModel 管理页面状态与流程编排。
- Repository 封装 API、存储和数据映射。
- 跨页面流程使用少量 Coordinator/Service，不强制每个动作建立 UseCase。
- Riverpod 提供状态和依赖注入，但不改变 MVVM 职责边界。
- Swift/SwiftUI 是 iOS presentation adapter，不成为第二套 ViewModel 或业务层。

## 理由

- 与 Flutter 声明式 UI 和 Riverpod 的单向状态流匹配。
- 页面状态能脱离 Widget 做纯 Dart 测试。
- feature-first 降低跨模块修改范围，便于拆小文件。
- 相比 MVC，避免 Controller 同时承担导航、网络、状态和平台桥接。
- 相比完整 Clean Architecture，减少无实际价值的 entity/usecase/mapper 空壳层。

## 后果

- 必须遵守 View -> ViewModel -> Repository 的单向依赖。
- 共享能力需要明确进入 core/shared，不能跨 feature 偷引 presentation。
- 会增加少量状态类与接口文件，但换取可测试性和职责稳定。
- 任何主架构或核心基础设施变更都需要新 ADR 和项目所有者明确确认。

## 非目标

- 不要求每个 DTO 都复制一份 domain entity。
- 不要求每个 Repository 方法都有 UseCase。
- 不用抽象基类统一所有 ViewModel。
- 不追求“一文件一个五行类”的机械拆分。
