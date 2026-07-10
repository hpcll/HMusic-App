# 03 · 设计系统（1:1 复刻依据）

> 读者：写 UI 的人。全部数值取自 `HMusic-Server/web/styles.css`（1201 行），逐条核对。
> 客户端直接复用这份 CSS，本文是「为什么长这样」的说明书 + 换技术栈时的复刻清单。
> 风格自述：**feather.computer 风 —— 暖纸色底 / 墨色文字 / 细边框 / 衬线展示标题 / 克制阴影**。

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
  （`flex:1; overflow-y:auto`，唯一滚动者）→ 底部导航（**流内底栏**，
  `env(safe-area-inset-bottom)` 安全区）。
  > 铁律：tab 栏是应用骨架，必须永远可见。**勿用 position:fixed 悬浮实现**——
  > 部分浏览器内核/底部工具栏会盖住或废掉 fixed 底栏（症状：滚到页尾才见 tab）。
  > Flutter 的 `Scaffold(bottomNavigationBar:)` 天然就是这个结构，照用即可。
- 内容区 `.view`：`padding:40px 48px 56px; max-width:880px; margin:0 auto; gap:22px`。
  窄屏 `padding:18px 16px 32px; gap:16px`。
- **grid 子项防溢出**：`.view > * { min-width:0 }`，配合 `.track-row{min-width:0}`——否则
  超长歌名（nowrap）会撑宽整页，破坏 `text-overflow:ellipsis`。**移植时必须保留。**

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

### 模态框（Teleport 到 body）
`.modal-overlay` 全屏 `rgba(0,0,0,.42)` + `blur(2px)`，flex 居中，点遮罩关闭。
`.modal-card` max-width420 radius10 shadow-pop，head(标题+✕) / body(滚动) / foot(右对齐按钮)。

### Toast
`position:fixed; bottom:28px(窄屏92px); 居中; padding:10px 20px; radius-sm; shadow-pop`
左边框 3px 表意：info→muted-2 / success→accent / error→danger(且字变红)。3.2s 自动消失。

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

**歌词滚动**：当前行 `scrollIntoView({behavior:"smooth", block:"center"})`。
歌词栏上下渐隐 `mask-image: linear-gradient(transparent,#000 12%,#000 88%,transparent)`（纸卷感）。

## 5. 复刻取舍（换技术栈时才需要；Tauri 复用 CSS 则跳过）

若某天在非 web 技术栈复刻：
- 优先级 = token（色/圆角/字体）> track-row 原子 > 按钮族 > 布局骨架 > 动效
- 深浅色用系统 `prefers-color-scheme`，两套 token 全量给出
- 衬线展示标题是灵魂，别用无衬线糊弄
- 青绿的「仅点缀」纪律是这套设计的克制感来源，最易被破坏，重点守住

## 实现状态
- [x] token/组件/动效 全量记录（源：web/styles.css）
- [ ] Tauri 复用验证（深浅色、衬线字体在 WKWebView/WebView2 的可用性）
