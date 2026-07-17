# 03 · 设计系统（内容复刻 + 平台材质）

> 读者：写 UI 的人。数值源自 `HMusic-Server/web/styles.css`，Flutter 需映射为 ThemeExtension、
> 组件约束与 golden test；不直接复用 CSS。
> 风格自述：**feather.computer 风 —— 暖纸色底 / 墨色文字 / 细边框 / 衬线展示标题 / 克制阴影**。
> 平台增强：内容层保持上述品牌；iOS 27 的系统 chrome 使用 Swift/SwiftUI 原生液态玻璃，
> Android 使用 Flutter 同构玻璃材质。玻璃是导航与控制层，不替代内容设计。

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

### 深色（@media prefers-color-scheme:dark）
```
--bg:#131315 --panel:#1b1b1e --panel-2:#232326
--text:#d6d6d8 --text-strong:#f0f0f2 --muted:#85858a --muted-2:#a3a3a8
--line:#313135 --line-soft:#29292d --ink:#e6e6e9 --ink-hover:#ffffff
--accent:#2ec4b8  --shadow/--shadow-pop 加深
```

### 平台玻璃 token

这些 token 只用于 Android/旧 iOS 回退；iOS 27 原生材质优先由系统决定折射、模糊与高光：

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
> 队列当前行、扫码成功、toast 成功、榜单播放次数计数。**从不用于装饰或静态强调**。
> 强调「第一名/焦点」一律用衬线 + 加深墨色（`.chart-rank.top` 范式），不用颜色。

### 字体
- 正文栈：`Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif`；base `15px / line-height 1.55`
- 衬线展示（`--font-serif`）：用于 品牌名、各页大标题 `.view-title`、播放页曲名/当前歌词行、
  统计大数字、榜单卡名、第一名排名。这是这套 UI 的「刊物腔调」，务必保留。
- 等宽（代码框）：`"Geist Mono", ui-monospace, SFMono-Regular, Menlo, monospace`

## 2. 布局骨架与响应式

**唯一断点：860px**（`max-width:859px` 窄屏 / `min-width:860/861px` 桌面）。另有 520px（表单 split 转单列）、1023px（播放页双栏转单列）。

- **桌面（≥860px）**：`grid-template-columns: 232px 1fr` = 左固定侧边栏 + 右内容区。
  侧边栏 `position:sticky; height:100vh`，含：品牌 / 导航（7 项）/ 底部 mini 播放状态 + 用户。
- **窄屏（<860px）**：**内滚动应用壳**——壳 = 视口高（`100dvh`，旧 iOS 回退
  `-webkit-fill-available`），flex 纵排：顶栏（`.topbar`，毛玻璃）→ 内容区
  （`flex:1; overflow-y:auto`，唯一滚动者）→ 底部导航。
  > web 的「流内底栏、勿用 position:fixed」铁律是浏览器内核特有顾虑，App 端不适用。
  > App 底部导航为**悬浮玻璃胶囊 dock**（对齐 iOS 26+ 原生液态玻璃壳形态）：
  > 胶囊压进安全区、悬在 home indicator 上方，mini player 胶囊叠在 dock 上方；
  > 仍挂 `Scaffold(bottomNavigationBar:)` 槽位，骨架恒在——tab 页内 dock 永远
  > 可见，不整体消失：向下滚收缩为「mini 内联 + 当前 tab 图标圆钮」等高一排，
  > 只有滚回顶部（或点圆钮/切 tab）才展开，中途向上滚保持收缩。
- 内容区 `.view`：`padding:40px 48px 56px; max-width:880px; margin:0 auto; gap:22px`。
  窄屏 `padding:18px 16px 32px; gap:16px`。
- **grid 子项防溢出**：`.view > * { min-width:0 }`，配合 `.track-row{min-width:0}`——否则
  超长歌名（nowrap）会撑宽整页，破坏 `text-overflow:ellipsis`。**移植时必须保留。**

### 平台 chrome 分层

| 区域 | iOS 26+ | Android / iOS<26 | 内容原则 |
|---|---|---|---|
| 顶栏 | Swift/SwiftUI 系统液态玻璃 | Flutter AdaptiveGlassSurface | 标题简短，不承载功能说明；底缘不画 hairline（web .topbar 的 border-bottom 不搬），tint 底部 20% 渐隐收边，off 档退实底并保留底线分界 |
| 底部导航 | 原生液态玻璃悬浮 dock | Flutter 毛玻璃悬浮 dock（同形态） | 高 66，导航主锚点；胶囊压安全区悬浮，滚动收缩为图标圆钮（高 50，与内联 mini 等高一排） |
| mini player | 原生玻璃胶囊（dock 上方） | Flutter 毛玻璃胶囊（同形态） | 高 50、封面 32——比 dock 矮一档的次级状态条；封面、题/歌手、播放与下一曲，收缩时内联到圆钮左侧、内容不裁剪 |
| 播放主控/音量浮层 | 原生材质优先 | Flutter 玻璃面板 | 控件尺寸固定，不因状态位移 |
| 模态/菜单 | 原生玻璃或系统 sheet | Flutter 玻璃 overlay | 表单主体可保持不透明以保证可读性 |
| 歌单卡、曲目行、统计图 | 不使用玻璃 | 不使用玻璃 | 延续暖纸/墨色内容风格 |

禁止“每张卡片都 BackdropFilter”。背景层不足时玻璃没有信息价值，只会降低文字对比并增加 GPU 成本。

桌面端：三桌面平台的 chrome（mini player、窄窗顶栏/底栏）同用 Flutter
`AdaptiveGlassSurface`（blur + 提饱和 + 顶缘高光）；macOS 窗体另垫窗后毛玻璃
（`NSVisualEffectView.sidebar`），侧栏半透明透出壁纸；Windows/Linux 无窗后采样能力，
侧栏保持不透明暖纸。高对比/减动效环境下玻璃统一降级为不透明面板（off 档）。

## 3. 核心组件规格

### 卡片 .card
`background:panel; border:1px line; radius:10px; padding:20px; box-shadow:--shadow; display:grid; gap:14px`

### 按钮族
| 类 | 边框/底/字 | 悬停 |
|---|---|---|
| `.primary-btn` | ink 底 / bg 字（墨底白字） | ink-hover |
| `.secondary-btn` | line 边 / panel 底 / text 字 | 边→muted |
| `.danger-btn` | 透明 / danger 字 | 边→danger |
| `.ghost-btn` | 无边透明 / muted-2 字，小号 | 底→panel-2 |
公共：`radius-sm; padding:9px 18px; font 13.5px/500; transition .12s; disabled opacity.5`

### 曲目行 .track-row（全站复用的列表原子）
`flex; gap:13px; padding:10px 12px; radius-sm; border-bottom:1px line-soft; hover底→panel`
- `.track-cover` 44×44 radius6 封面（`center/cover`，无图显 ♪/note 图标）
- `.track-info` flex:1 min-width:0 → `.track-title`(14px/500/strong,nowrap ellipsis) + `.track-artist`(12.5px/muted)
- `.track-actions` 桌面 hover 才显（`@media (hover:hover) and (min-width:860px)` opacity 0→1），触屏常显
- `.track-cols`（≥861px）：`grid 1fr 1fr; column-gap:28px` 宽屏双列（榜单/歌单详情，50 首减半滚动）

### 圆形图标按钮
- `.icon-btn` 34×34 圆 / line 边 / hover 边→strong；svg 16px
- 播放页主控 `.ctrl-btn` 46×46 圆；`.ctrl-btn.primary` 64×64 ink 底白字（播放键），active `scale(.95)`

### 导航项
- 桌面 `.side-item`：flex，muted-2 字，hover 底→panel-2；**active：底→text-strong，字→bg（墨底反白）**
- 窄屏 `.nav-item`：竖排 icon+label 10.5px，active 字→text-strong；图标 21px

### 状态点 .dot（7px 圆）
`dot-playing:accent` / `dot-paused:#c99700` / `dot-idle/stopped:muted` / `dot-error:danger`

### 模态框（Flutter Dialog/Overlay）
`.modal-overlay` 全屏 `rgba(0,0,0,.42)` + `blur(2px)`，flex 居中，点遮罩关闭。
`.modal-card` max-width420 radius10 shadow-pop，head(标题+✕) / body(滚动) / foot(右对齐按钮)。

### Toast
`position:fixed; bottom:28px(窄屏92px); 居中; padding:10px 20px; radius-sm; shadow-pop`
左边框 3px 表意：info→muted-2 / success→accent / error→danger(且字变红)。3.2s 自动消失。
App 适配（web 的 28/92 按其底边 chrome 定）：底距必须避让本壳底部 chrome——桌面抬到
悬浮 mini 包络（76）+12 并水平居中于侧栏右侧内容区；窄屏抬到悬浮玻璃 chrome 完整包络
之上（底距 + dock 66 + gap 8 + mini 50 + 呼吸距 8，随安全区上浮）。

### 输入
`width:100%; border:1px line; radius-sm; padding:9px 12px; font14; focus 边→text-strong`

## 4. 动效清单（全部 transition，无重动画）

| 选择器 | 属性 | 时长/缓动 |
|---|---|---|
| 侧边栏项/菜单行 | background, color | .12s ease |
| 按钮族/卡片/输入/图标按钮 | border-color/background/color | .12s ease |
| 主控播放键 :active | transform scale(.95) | .12s ease |
| 歌词行 | color, font-size（当前行放大变衬线） | .25s ease |
| 音量 flyout | opacity（悬浮展开，不占布局） | .2s ease |
| track-actions 显隐 | opacity | .12s ease |
| toast | 无动画，纯出现/消失 | — |

平台玻璃额外动效：

| 场景 | iOS 26+ | Android / iOS<26 |
|---|---|---|
| tab 切换 | 使用系统材质选择态与连续形变 | 180-240ms 高光/透明度过渡 |
| mini player 显隐 | 系统 spring/玻璃容器尺寸变化 | 220ms easeOut 高度过渡 |
| dock/mini 滚动收缩、展开 | 系统 spring（response .42 / damping .86） | 220ms easeOut 尺寸变化（AnimatedSize） |
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
- iOS 27 使用真实系统材质截图验收，golden test 只覆盖 Flutter 内容与回退壳
- Android 至少验证高画质、普通画质、无模糊三档，文字对比和布局必须一致

## 实现状态
- [x] token/组件/动效 全量记录（源：web/styles.css）
- [ ] Flutter ThemeExtension 与字体资产落盘
- [ ] 深浅色 golden test
- [ ] iOS 27 Swift/SwiftUI 液态玻璃 shell 视觉 spike
- [ ] Android AdaptiveGlassSurface 三档降级 spike
