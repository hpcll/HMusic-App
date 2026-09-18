# 03 · 设计系统（内容复刻 + 平台材质）

> 读者：写 UI 的人。数值源自 `HMusic-Server/web/styles.css`，Flutter 需映射为 ThemeExtension、
> 组件约束与 golden test；不直接复用 CSS。
> 风格自述：**feather.computer 风 —— 暖纸色底 / 墨色文字 / 细边框 / 衬线展示标题 / 克制阴影**。
> 平台增强：内容层保持上述品牌；iOS 26+ 的系统 chrome 使用 Swift/SwiftUI 原生液态玻璃，
> Android 使用 Flutter 同构玻璃材质。玻璃是导航与控制层，不替代内容设计。
> 2026-09-07：App 的导航与响应式规格以本章及 [13 实施方案](13-ui-modernization-plan.md) 为准，
> Web 的 CSS 数值只作为品牌参考，不再作为客户端断点或交互约束。

## 1. 设计 token

### 亮色（:root）
```
--bg: #f7f7f8        页面底         --panel: #ffffff      卡片面
--panel-2: #f0f0f1   次级面         --text: #333333       正文
--text-strong:#1a1a1a 强调文字/主操作 --muted: #999999      弱化文字
--muted-2: #777777   次弱化         --line: #e3e3e5       边框
--line-soft:#ececee  更浅分隔       --ink: #1a1a1a        主按钮底
--ink-hover:#000000  主按钮悬停     --accent: #21b0a5     品牌青绿(仅点缀)
--danger: #b91c1c
--shadow: 0 1px 2px rgba(0,0,0,.04)
--shadow-pop: 7px 15px 36px 4px rgba(0,0,0,.1)
--radius:10px  --radius-sm:7px  --sidebar-w:232px
--font-serif: "Songti SC","Noto Serif SC",Georgia,"Times New Roman",serif
```

> **App 端圆角分叉**（源 `HMusicRadii`）：web 的 10/7 在 App 放大为
> `card/input:14`、`small:10`，按钮全胶囊（StadiumBorder）——移动端整体偏软的
> 胶囊语言（对齐 dock/mini/搜索框），web 保持 10/7，这组值两侧不再互相同步。

### 深色（@media prefers-color-scheme:dark）
```
--bg:#131315 --panel:#1b1b1e --panel-2:#232326
--text:#d6d6d8 --text-strong:#f0f0f2 --muted:#85858a --muted-2:#a3a3a8
--line:#313135 --line-soft:#29292d --ink:#e6e6e9 --ink-hover:#ffffff
--accent:#2ec4b8  --shadow/--shadow-pop 加深
```

### 平台玻璃 token

这些 token 只用于 Android/旧 iOS 回退；iOS 26+ 原生材质优先由系统决定折射、模糊与高光：

```text
glassTintLight:  rgba(255,255,255,.62)
glassTintDark:   rgba(28,28,30,.58)
glassBorder:     white/black 低透明高光边
glassShadow:     0 8px 28px rgba(0,0,0,.10)
glassBlurHigh:   24-32
glassBlurMedium: 16-20
glassBlurOff:    0（性能/降低透明度回退）
```

玻璃 tint 必须保持中性，禁止把品牌青绿铺成整块玻璃。青绿仍只表达正在播放、成功和当前项。

> **青绿 --accent 的铁律**（全站仅 5 处用它）：只表达「正在发生的事」——在播状态点、
> 队列当前行、扫码成功、行尾 ✓ 确认、榜单播放次数计数。**从不用于装饰或静态强调**。
> 强调「第一名/焦点」一律用衬线 + 加深墨色（`.chart-rank.top` 范式），不用颜色。

### 字体
- 正文栈：`Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif`；base `15px / line-height 1.55`
- 衬线展示（`--font-serif`）：用于 品牌名、各页大标题 `.view-title`、播放页曲名/当前歌词行、
  统计大数字、榜单卡名、第一名排名。这是这套 UI 的「刊物腔调」，务必保留。
- 等宽（代码框）：`"Geist Mono", ui-monospace, SFMono-Regular, Menlo, monospace`

## 2. 布局骨架与响应式

App 外壳按视口宽度分三档，统一由 `shared/layout/shell_metrics.dart` 决定：

| 视口宽度（逻辑像素） | 导航 | 内容 |
|---|---|---|
| <700 | 底部恢复原四入口：榜单 / 歌单 / 统计 / 设置 | 页面滚动，底部 mini + dock |
| 700–1023 | 80 宽 rail | 保留七条路由，图标有 tooltip 与语义标签 |
| ≥1024 | 232 宽分组侧栏 | 浏览、曲库与回顾、播放、设置；底部常驻桌面播放条 |

- 保留原七条 branch 的索引、路径及 native id；统计恢复独立底栏入口，歌单内的 NAS 内容继续可达。
- 页面分栏用 `LayoutBuilder` 的实际内容宽高，不能再次按整机宽度推断可用空间。
  设置菜单宽为 `240 * max(1, scale(14)/14)`，双栏还须容纳间距 32、正文至少 480 和两侧 32；
  基础字时内容宽需 784、2 倍字时需 1024，否则用菜单→详情。
- 手机顶部保留 `TopEdgeScrim` 渐进模糊与轻提亮；品牌在登录页，退出在设置菜单。
  Flutter dock 位于 `Scaffold(bottomNavigationBar:)`，内容通过注入的 padding 避开 chrome。
- mini 和 dock 展开/收缩共用尺寸函数。字号超过 1.2 倍，或收缩后 mini 宽不足 160 时，
  始终展开；普通手机向下滚收起，向上滚、点导航圆钮或切 tab 展开，横滑不影响底栏。
- iPad 切到 rail/sidebar 时同步隐藏 native dock/mini；旋转也要重新报告 inset，避免双层导航。
- 只有 macOS 为现有隐藏标题栏额外预留 28；Windows/Linux/iPad 不统一添加该空白。
- 桌面恢复适用的滚动条；榜单改完整网格，嵌套列表不共用错误的 ScrollController。
- 长曲名用 `Flexible/Expanded` 和 ellipsis 约束，表单和控制区按内容宽度换行；字体允许到 2 倍，
  不通过缩小系统文字掩盖溢出。

### 平台 chrome 分层

| 区域 | iOS 26+ | Android / iOS<26 | 内容原则 |
|---|---|---|---|
| 顶部边缘 | 无 chrome：滚动消融（TopEdgeScrim 渐进模糊 + 轻纱帘） | 同左（shader 逐像素变径的单层 backdrop，结构零缝；非 Impeller/编译前退纯纱帘，off 档退不透明渐变） | 无常驻顶栏；品牌见登录页、退出在设置菜单底部；内容透过状态栏区仍可见，越靠顶越糊越淡，无条无线 |
| 底部导航 | UIKit 系统液态玻璃 dock | Flutter 毛玻璃 dock | 原四入口；Flutter 基础高 62、大字按 `mobileDockHeight` 增高；原生 dock 高度由 UIKit 回报，收起圆钮与 mini 等高 |
| mini player | 原生玻璃胶囊（dock 上方） | Flutter 毛玻璃胶囊（同形态） | 恢复基础高 50 的封面、曲名/歌手、播放和下一首；收起时只留封面、曲名和播放，无曲目显示“未在播放” |
| 播放主控/音量浮层 | 原生材质优先 | Flutter 玻璃面板 | 控件尺寸固定，不因状态位移 |
| 模态/菜单 | 原生玻璃或系统 sheet | Flutter 玻璃 overlay | 表单主体可保持不透明以保证可读性 |
| 歌单卡、曲目行、统计图 | 不使用玻璃 | 不使用玻璃 | 延续暖纸/墨色内容风格 |

禁止“每张卡片都 BackdropFilter”。背景层不足时玻璃没有信息价值，只会降低文字对比并增加 GPU 成本。

桌面端：三桌面平台的 chrome（mini player、窄窗底部 dock）同用 Flutter
`AdaptiveGlassSurface`（blur + 提饱和 + 顶缘高光）；macOS 窗体另垫窗后毛玻璃
（`NSVisualEffectView.sidebar`），侧栏半透明透出壁纸；Windows/Linux 无窗后采样能力，
侧栏保持不透明暖纸。高对比/减动效环境下玻璃统一降级为不透明面板（off 档）。

手机 mini 保持原来的两行外观，字号为 14/12、行高 1.25；高度统一为
`max(50, ceil(14 + (scale(14) + scale(12))*1.25))`，1.5 倍字为 63、2 倍为 79。
收起态为左侧当前导航圆钮、中间 mini、右侧搜索圆钮；圆钮与 mini 等高。
移除手机 mini 上额外增加的设备行和输出按钮，设备选择保留在完整播放器中。
Swift 消费 Flutter 传入的高度和缩放字号，不另算一套。桌面使用 `DesktopPlaybackBar`，
按实际内容宽度排为三段或多行，外壳通过同一个 `desktopPlaybackBarHeight` 预留完整包络。

## 3. 核心组件规格

### 卡片 .card
`background:panel; border:1px line; radius:10px; padding:20px; box-shadow:--shadow; display:grid; gap:14px`
App 适配：radius → 14（`HMusicRadii.card`，§1 圆角分叉），其余不变。

### 按钮族
| 类 | 边框/底/字 | 悬停 |
|---|---|---|
| `.primary-btn` | ink 底 / bg 字（墨底白字） | ink-hover |
| `.secondary-btn` | line 边 / panel 底 / text 字 | 边→muted |
| `.danger-btn` | 透明 / danger 字 | 边→danger |
| `.ghost-btn` | 无边透明 / muted-2 字，小号 | 底→panel-2 |
公共：`radius-sm; padding:9px 18px; font 13.5px/500; transition .12s; disabled opacity.5`
App 适配：Filled/Outlined 全胶囊（StadiumBorder、padding 水平 20）——与 dock/mini/
搜索框的胶囊语言统一；ghost/danger 文本按钮形态不变。

### 曲目行 .track-row（全站复用的列表原子）
`flex; gap:13px; padding:10px 12px; radius-sm; border-bottom:1px line-soft; hover底→panel`
- `.track-cover` 44×44 radius6 封面（`center/cover`，无图显 ♪/note 图标）
- `.track-info` flex:1 min-width:0 → `.track-title`(14px/500/strong,nowrap ellipsis) + `.track-artist`(12.5px/muted)
- `.track-actions` 桌面 hover 才显（`@media (hover:hover) and (min-width:860px)` opacity 0→1），触屏常显
- `.track-cols`（≥861px）：`grid 1fr 1fr; column-gap:28px` 宽屏双列（榜单/歌单详情，50 首减半滚动）

以上 CSS 为 Web 参考。App 搜索与 NAS 复用 `HMusicAdaptiveTrackRow`：手机为封面与两行信息，
宽屏按歌曲、歌手/专辑、时长、已有来源分列；列数取决于内容宽度，动作区保留固定宽度。
不存在的元数据不虚构；操作延续原 VM 的在途禁用、行内确认和错误反馈。

### 首页推荐自定义（2026-09-18 工作树新增）

“发现榜单”标题右侧提供带语义标签的“首页推荐管理”按钮。管理弹窗按榜单列出开关与
48px 拖动手柄，可调整跨平台/个人榜的首页顺序；保存才生效，取消丢弃草稿，恢复默认仍需保存。
首次保持各公开来源一个精选榜及已有个人常听榜；用户可开启其他榜单。精选区统一混排，
不再以固定个人/公开分区限制排序；平台分类保留完整目录。至少保留一个当前可用推荐榜单，
最后一项开关禁用并说明原因，保存层同步校验；旧偏好全关或目录缩减时自动展示首个可用榜单。
偏好仅本机持久化，三模式共用，不改 Server 配置；目录暂时缺项不清除选择。

### 榜单卡 .chart-card（App 端偏离）
2026-09-08：榜单页统一为“我的 Spotify 榜单”和“发现榜单”两层。个人榜三个周期
进入页面即预取；发现区默认每个来源只展示一个精选榜，点击来源筛选浏览完整目录。
不再用主推轮播重复展示后面的榜单，也不在榜单页放账号设置入口。
卡头增加来源/统计时段小字；失败时在卡内给出原因与重试，空记录与加载失败分开显示。
个人区手机可横滑、宽屏并列；发现区使用随内容宽度和字号调整的网格。
来源标签保持单行，窄屏横向滑动，宽屏空间足够时完整平铺；保留至少 44px 触达高度，
标签随系统字号增大，不折成多排挤占榜单内容。
点选后只平移标签行，将选中项移向中间并露出邻近分类；首尾停在内容边界，
不移动页面的纵向位置。过渡 220ms，遵循系统减动效设置立即定位。

卡头（#1 封面 48 + 衬线榜名）+ Top3 可点播预览。**整卡点击进详情，卡内不放「查看全部」
文字行**——与整卡点击同义的第二入口，删掉换来预览区呼吸。分区小节标题同理不带 chevron：
卡带已陈列该来源全部榜单，分区层级没有「更多」目的地（Apple Music 的「›」都真的可点进
下级页，有指无路是假承诺）。
封面为 48×48 方形；Top3 的歌名、歌手分层。卡片及预览包络随 `TextScaler` 增高，
不钳制系统字号；桌面改完整网格，所有榜单可随页面垂直滚动到达。

### 歌单占位封面
按歌单 id/name 确定字形、几何和墨色层次，同一歌单展示稳定，浅深色均可读。
本轮不逐张请求详情获取封面；真实摘要封面数据任务见 13 §8。删除放在“更多”菜单，保留确认。

### 圆形图标按钮
- `.icon-btn` 34×34 圆 / line 边 / hover 边→strong；svg 16px
- 播放页主控 `.ctrl-btn` 46×46 圆；`.ctrl-btn.primary` 64×64 ink 底白字（播放键），active `scale(.95)`
- App 小圆按钮视觉可为 34，但整个至少 44×44 区域必须响应点击；tooltip 与语义保留。
  `HMusicConfirmButton` 复用同一命中实现，在途及确认驻留期间禁止重复提交。

### 导航项
- 桌面 `.side-item`：flex，muted-2 字，hover 底→panel-2；**active：底→text-strong，字→bg（墨底反白）**
- 窄屏 `.nav-item`：竖排 icon+label 10.5px，active 字→text-strong；图标 21px
  App 适配（悬浮 dock）：iOS 26+ 展开态直接使用公开的 `UITabBarController` 默认
  Liquid Glass tab bar，不自绘选中气泡、不实现拖动手势。气泡越界、融合收腰、按住滑动、
  吸附和后续系统调整全部由 UIKit 提供；Swift delegate 只把选中的 tab id 回传为语义 intent。
  滚动收缩后的单图标圆钮仍由薄 SwiftUI overlay 承载。“降低透明度”由系统无障碍外观接管。
  Android / iOS<26 保持同形灰药丸；点按无矩形水波，反馈由选中气泡承担。

### 状态点 .dot（7px 圆）
`dot-playing:accent` / `dot-paused:#c99700` / `dot-idle/stopped:muted` / `dot-error:danger`

### 模态框（Flutter Dialog/Overlay）
`.modal-overlay` 全屏 `rgba(0,0,0,.42)` + `blur(2px)`，flex 居中，点遮罩关闭。
`.modal-card` max-width420 radius10 shadow-pop，head(标题+✕) / body(滚动) / foot(右对齐按钮)。

### 操作反馈（App：toast 已移除，2026-09-06 起对齐 Apple「就地反馈」）
App 不再使用浮层 toast（浮层遮挡内容、与内容流脱节，用户评审定为「丑」）。反馈
出现在它发生的上下文里：
1. **行内操作成功** → 行尾按钮原地转青绿 ✓ 驻留 1.6s 回弹（`HMusicConfirmButton`，
   Apple Music「已添加」同款）；下载另有 ↓/菊花/✓ 三态。
2. **状态自明的成功**（创建/删除/刷新/播放开始等）→ 不出任何消息，状态变化即反馈。
3. **错误与不可见结果**（导入统计、插件测试、收藏失败等）→ `HMusicInlineNotice`
   就地内联一行（success ✓ accent / error ⚠ danger / info 灰字，13px），渲染在
   所在 section 顶部、页面页头下方或播放控制行下；生命周期归 VM，下次动作覆盖。
4. **播放链路全局失败** → 状态点/播放页状态承担反馈；壳层只保留小米会话过期的
   限频回读让横幅（持久条件条，非 toast）及时出现。
web 端不受此节约束；`hmusic_toast.dart` 仅存档，不作为新页面的反馈出口。

### 输入
`width:100%; border:1px line; radius-sm; padding:9px 12px; font14; focus 边→text-strong`
App 适配：灰底（panel-2）无描边、radius 14、padding 14/12，focus 不加描边
（可见性由光标承担，与搜索框同纪律）——移动端软表单款，web 描边款不变。
搜索页例外：搜索框使用平台自适应玻璃胶囊，结果列表使用稳定内容面板；禁止逐行建立
BackdropFilter，玻璃只用于导航、输入与控制层。
榜单页头搜索胶囊：材质随吸顶进度过渡——展开态背后是纯暖纸，玻璃无内容可采样、只剩
hairline 圈（违背无线北极星），故垫 panel-2 读作灰底填充；吸顶后垫层随 progress 淡出，
玻璃直接采样滚过的内容。hairline 恒关（同 toast/横幅的 Apple Music 无线语言）。

## 4. 动效清单（全部 transition，无重动画）

| 选择器 | 属性 | 时长/缓动 |
|---|---|---|
| 侧边栏项/菜单行 | background, color | .12s ease |
| 按钮族/卡片/输入/图标按钮 | border-color/background/color | .12s ease |
| 主控播放键 :active | transform scale(.95) | .12s ease |
| 歌词行 | color, font-size（当前行放大变衬线） | .25s ease |
| 音量 flyout | opacity（悬浮展开，不占布局） | .2s ease |
| track-actions 显隐 | opacity | .12s ease |
| toast | web 无动画；App 已移除 toast（见「操作反馈」），行尾 ✓ 驻留/回弹 1.6s | easeOutCubic / easeIn |
| 可点元素按压（App） | transform scale .97（`PressableScale`） | 120ms easeOut |
| 骨架 → 内容（App） | opacity 交叉淡化（`AnimatedSwitcher`） | 180ms easeOut / easeIn |
| 远程图首帧到达（App） | opacity 0→1，垫深色占位在底层防白闪 | 200ms easeOut |

**App 按压纪律**：可点元素统一用 `PressableScale`（scale .97 / 120ms），不用 Material
矩形水波——iOS 上涟漪出戏，且水波的矩形/圆角包络与胶囊语言冲突。滚动容器内安全
（滑动触发 tapCancel 立即回弹）。减动效环境所有 App 侧动效直切（`disableAnimationsOf`）。

平台玻璃额外动效：

| 场景 | iOS 26+ | Android / iOS<26 |
|---|---|---|
| tab 切换 | `UITabBarController` 系统默认 Liquid Glass 选择、按住滑动与吸附；不维护自定义曲线 | 260ms easeOutCubic 药丸滑动（AnimatedAlign）+ 颜色过渡 |
| mini player 显隐 | 系统 spring/玻璃容器尺寸变化 | 220ms easeOut 高度过渡 |
| dock/mini 滚动收缩、展开 | SwiftUI 容器过渡与系统 dock；真机效果单独验收 | 320ms easeOutCubic，共用一条进度：dock 收到左侧圆钮，mini 缩窄居中下落，右侧搜索淡入；歌手和下一首同步让位 |
| 按压 | 系统液态反馈 | 100-140ms scale 0.97 + 高光变化 |
| 滚动经过 chrome | 系统自动采样背景 | 动态模糊仅高画质开启 |

不手工模仿未知的 iOS 折射曲线；有系统 API 就用系统 API，没有就回退到稳定材质。

**歌词滚动**：当前行 `scrollIntoView({behavior:"smooth", block:"center"})`。
歌词栏上下渐隐 `mask-image: linear-gradient(transparent,#000 12%,#000 88%,transparent)`（纸卷感）。
App 适配：按真实渲染几何（ensureVisible）把当前行钉在视口 0.4 锚点（中线略偏上）；
列表首尾留白随视口等比（顶 40%、底 60%），第一句和最后一句也停在同一锚点，不被边界顶走。

## 5. Flutter 复刻优先级

- 优先级 = token（色/圆角/字体）> track-row 原子 > 按钮族 > 布局骨架 > 动效
- 深浅色用 Flutter `ThemeMode.system`，两套 token 全量映射为 ThemeExtension
- 衬线展示标题是灵魂，别用无衬线糊弄
- 青绿的「仅点缀」纪律是这套设计的克制感来源，最易被破坏，重点守住
- 用 golden test 固定手机/平板/桌面关键宽度，和 Server web 截图并排验收
- iOS 26+ 使用真实系统材质截图验收，golden test 只覆盖 Flutter 内容与回退壳
- Android 至少验证高画质、普通画质、无模糊三档，文字对比和布局必须一致

## 实现状态
- [x] token/组件/动效 全量记录（源：web/styles.css）
- [ ] Flutter ThemeExtension 与字体资产落盘
- [ ] 深浅色 golden test
- [ ] iOS 26+ Swift/SwiftUI 液态玻璃 shell 真机视觉验收（本轮结果见 13 交付记录）
- [ ] Android AdaptiveGlassSurface 三档降级 spike
