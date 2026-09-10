# 全平台 UI 优化最终审查

日期：2026-09-07。方案：[13 全平台 UI 优化实施方案](../13-ui-modernization-plan.md)。

当前状态：本轮客户端实现与代码审查通过；Dart 统一门禁、可用宿主构建与关键布局复核完成。
真机交互及 Windows/Linux 宿主验收仍未完成，不作为本轮自动化验证的通过项。
没有提交、推送、发布或调用真实音箱播放命令。

## 范围与分工

| 执行包 | 实现范围 | 主审重点 |
| --- | --- | --- |
| A：shell_ui | 三档导航、三入口、统计归属、原生 viewport/inset、设置响应式 | 七条 branch 不变、原生/Flutter 互斥、无障碍与返回 |
| B：playback_ui | 桌面播放条、动态 mini、短横屏播放器、本机能力门禁 | 共用 handler、音量分流、尺寸一致、遥控保留 |
| C：content_ui | 曲库根分段、歌单占位与更多、共享曲目列、榜单网格、下载文案 | 原功能保留、隐藏页面返回、长文字、无额外封面请求 |
| 主 agent | 方案、共享按钮命中区、独立代码审查、集成检查、文档回填 | 实际运行证据与未验收范围分开记录 |

主审基线保留了开工时 7 个已修改文件的原内容、完整 patch、HEAD 与 tracked 文件散列。
原有 spinner、无描边输入、播放封面加载占位、按钮 hover/44 命中意图及路线图条目均作为保留项。
搜索页参数后意外混入的“继续”只做语法修正；`.claude-handoff-night.md` 与 `.zcode/` 未纳入修改。

## 审查发现与回修

| 编号 | 发现 | 修复与证据 |
| --- | --- | --- |
| REV-01 | 两个共享按钮虽然有 44 外框，实际 InkWell 只有内部 34，外圈点击不响应 | 主审先用点击四边用例复现，再将事件范围移到完整外框；确认按钮复用相同实现，3 项测试通过 |
| REV-02 | 设置菜单在 2 倍字时溢出 47px | 菜单宽度随文字增大，正文空间不足回单页；窗口切换继续保留表单实例 |
| REV-03 | native ready 晚到时把 reduceMotion/reduceTransparency 重置为 false | 保存最近 configure 并重放；补 late-ready 与无障碍配置回归 |
| REV-04 | 冷恢复时 Server 已有曲目而 handler MediaItem 仍空，播放条与外壳占位可能不同步 | Flutter 条与包络共用 Server track；app 层向 native 投影同一 metadata，playing 仍来自 handler |
| REV-05 | 新能力门禁所在旧音频 handler 达 585 行，超过工程门槛 | 保持同一 library/实例，拆初始化、状态应用、装载恢复、周期上报；音频与播放器 88 项定向测试通过 |
| REV-06 | 35 组预览均无 RenderFlex 异常，但小屏 2 倍字与短横屏 NAS 工具区把歌曲遮在播放条后面 | 改为单一 Sliver 滚动区；搜索、曲目入队、分组返回及 120 首分页末项的几何/点击回归通过，最终滚动前后截图复核通过 |
| REV-07 | 内容 Navigator 的 BlockSemantics 吞掉先绘制的同级侧栏，读屏看不到导航 | 给内容 Navigator 设置独立 Semantics 容器，使用实际 SideNavigationShell 测试七入口语义及点击 |
| REV-08 | 部分构建函数虽满足文件行数门槛，仍超过 docs/10 的方法/build 门槛 | 按职责抽出导航、设置、页面列表与设备空态；保留路由顺序、表单 GlobalKey 和语义边界 |
| REV-09 | Flutter mini 曲名与榜单预览有读屏标签，但 `excludeSemantics` 同时去掉内部手势的 tap | 主审测试复现 mini 并检查同类结构；显式绑定语义动作，mini 与布局 19 项、榜单读屏/触控 2 项通过；禁用与独立输出不串动作 |
| REV-10 | 宽设置默认显示小米面板却未记录 section，填写后缩窄会回菜单并丢失输入 | 使用真实默认面板复现，宽布局帧后记录默认选择并迁移原表单；新增默认入口、宽窄往返及返回菜单测试 |

其他已检查的行为：

- 原有七条 branch、路径与 native id 保留；手机统计归入曲库。
- 歌单/NAS 在 app 层组合，业务仍由原 feature VM 持有；NAS 首次访问加载。
- 主审额外挂真实曲库与外壳返回的集成测试，2 项通过：歌单详情逐级返回，以及统计回到原 NAS 分组。
- 桌面进度和歌词继续读取现有位置流；本机音量持续更新，音箱音量松手提交。
- 输出名称在 app 组合层投影给 native，原生没有新增网络、凭据或队列状态。
- 歌单占位使用稳定散列，无 N+1 详情或封面请求；搜索/NAS 共用曲目列展示。
- Windows/Linux 门禁只限制未接入的本机能力；没有新造 remote handler 或替换音频依赖。

## 统一验证记录

环境：Flutter 3.35.4 / Dart 3.9.2；macOS 宿主；Xcode 可用 iOS Simulator 26.5 与 macOS 26.5 SDK。
本轮没有修改 Server 契约或依赖版本。

| 检查 | 结果 |
| --- | --- |
| `dart format .` | 通过，404 个 Dart 文件；格式化未扩大到任务外文件 |
| `flutter analyze --no-pub` | 通过，No issues found；统一检查发现的 3 条 lint 已回修 |
| `flutter test --no-pub` | 通过，379 项测试 |
| iOS Simulator debug 构建 | 通过，`flutter build ios --simulator --debug --no-codesign --no-pub`，产物 `build/ios/iphonesimulator/Runner.app` |
| macOS debug 构建 | 无签名构建通过；默认 Flutter 构建因本机缺少 Mac App Development profile 失败，随后用 Xcode `CODE_SIGNING_ALLOWED=NO` 验证成功，未修改工程签名配置 |
| Android debug APK 构建 | 通过，`flutter build apk --debug --no-pub`，产物 `build/app/outputs/flutter-apk/app-debug.apk`；未据此勾选实机玻璃或后台验收 |
| 当前组件布局预览 | 最终 37 组无布局异常、无缺图；NAS 滚动前后、大小字号、横屏、断点与浅深色关键截图复核通过 |
| 本轮生产文件规模与 `git diff --check` | 117 个改动/新增生产文件无文件超限，Dart AST 方法/build 扫描无超限；差异检查通过 |

布局预览使用真实 Flutter 组件与示例状态，覆盖 Android/iOS/macOS/Windows/Linux 的主题及断点。
iOS 截图使用 Flutter 回退壳；部分系统字体由测试字体代替。harness 会捕获布局异常继续截图，
因此必须同时检查 `capture-manifest.json`、错误记录和图片，测试进程退出成功不能单独作为验收。

关键回归入口：

| 行为 | 测试 |
| --- | --- |
| 真实曲库与七分支壳的逐级返回 | [library_shell_navigation_test.dart](../../test/app/library_shell_navigation_test.dart) |
| 小屏/横屏 NAS 搜索、分组、分页末项点击 | [music_library_scroll_test.dart](../../test/app/music_library_scroll_test.dart) |
| 播放尺寸、设备入口与音量提交 | [playback_ui_layout_test.dart](../../test/features/player/playback_ui_layout_test.dart)、[player_volume_binding_test.dart](../../test/features/player/player_volume_binding_test.dart) |
| 默认设置面板与已选面板的宽窄草稿保留 | [settings_page_layout_test.dart](../../test/features/settings/settings_page_layout_test.dart) |
| mini/榜单预览读屏激活及禁用语义 | [mini_player_accessibility_test.dart](../../test/features/player/mini_player_accessibility_test.dart)、[chart_preview_song_test.dart](../../test/features/charts/chart_preview_song_test.dart) |
| 图标按钮透明外圈与确认期间防重入 | [hmusic_action_hit_target_test.dart](../../test/shared/widgets/hmusic_action_hit_target_test.dart) |

## 尚需真实设备或对应宿主验收

- iOS：UIKit dock 三入口命中、mini 输出按钮、原生字号、滚动收缩/展开、旋转 inset 与 native/Flutter 互斥。
- Android：系统字号、横屏、玻璃 High/Medium/Off 实际效果；原有 Adreno/Impeller 发布门禁继续有效。
- Android/iOS：后台连播、锁屏与系统中断仍须按既有音频验收表做真机复验，widget 测试不能替代。
- Windows/Linux：对应宿主编译与音箱遥控实测；本机音频后端、SMTC/MPRIS 尚未交付。

真实歌单/专辑封面摘要、完整设备 capabilities、全库“最近新增”排序、队列侧抽屉是方案中另列的
后续任务，不计入本轮完成项，也没有用模拟 API 或局部排序冒充实现。

## 交付结论

UI-01～10 中由现有客户端能力承接的范围已完成，执行 agent 交付后由主 agent 逐项审查并回修。
原七分支、用户既有改动及唯一播放 handler 保留；无新增依赖或 Server 契约变更。
本轮代码与可运行检查通过，可以进入真机及对应桌面宿主验收；这不是五端发布验收结论。

本机证据目录：
`/var/folders/cp/vgw9szn9731f34tqt45hf59m0000gn/T/hmusic-ui-audit-20260906-_an7h48h/`。
其中 `after/index.html` 是含 37 场景筛选和图片放大的改前/改后画廊，`after/capture-manifest.json`
记录每个样本的尺寸、字号、平台与错误；`after/first-pass/` 保留 NAS 首轮缺陷截图。
`validation/` 保存格式化、全仓分析/测试、三平台构建日志和规模扫描，默认 macOS 签名失败与随后
无签名成功分别记录。以上是本机生成的验证产物；可持续交接的规格、回归入口与缺口均已写入仓库文档。
