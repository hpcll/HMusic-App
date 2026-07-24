import SwiftUI

// SwiftUI 玻璃壳的唯一展示状态：全部由 Dart 经 channel 下发。
// Swift 不自行拉取或推导业务数据（docs/06 §3 铁律）。
// 类本身不做 availability 门禁：channel 在旧 iOS 上也持有它（仅不渲染），
// 只有用到 iOS 26 玻璃 API 的 View 层做 @available 门禁。
final class GlassShellState: ObservableObject {
  @Published var selectedTab: String = "charts"
  @Published var showTabBar: Bool = false
  @Published var showMiniPlayer: Bool = false
  @Published var trackId: String?
  @Published var trackTitle: String = ""
  @Published var trackArtist: String = ""
  @Published var artworkUrl: URL?
  @Published var playing: Bool = false
  // 滚动收缩态：Flutter 上报（向下滚收缩、滚回顶部展开）→ chrome 收成
  // mini 内联 + 当前 tab 图标圆钮的一排（对齐 Apple Music 收纳行为）。
  @Published var minimized: Bool = false
  // Dart configure 下发的降级补充；系统开关另经 SwiftUI Environment 直接生效，
  // 二者取 or（docs/06 §3 回退策略 3/4）。
  @Published var reduceMotion: Bool = false
  @Published var reduceTransparency: Bool = false
  // 底部安全区高度，由宿主从 UIKit window 注入（overlay 压安全区定位用）。
  @Published var bottomSafeArea: CGFloat = 0
  // iOS 27+ 用系统 UITabBarController 画 dock；26.x 系统玻璃与 SwiftUI
  // glassEffect 不同风格，由 overlay 自绘 dock 与 mini 统一材质。宿主 attach
  // 时一次性写入。
  @Published var usesSystemDock: Bool = true
  // UIKit 系统 tab bar 顶缘到屏幕底边的实际距离。
  @Published var systemDockClearance: CGFloat = 90
  // UIKit 系统 tab bar 底缘到屏幕底边的实际距离，收缩圆钮复用这条基线。
  @Published var systemDockBottomOffset: CGFloat = 24
  // 展开 mini player 和收缩行都跟随系统 tab bar 的实际左右边界。
  @Published var systemDockHorizontalInset: CGFloat = 20
}

// chrome 几何常量：SwiftUI 布局与 bottomInset 回报共用同一套数字，
// 保证 Flutter 让位高度与实际渲染严格一致。
enum GlassShellMetrics {
  static let dockHeight: CGFloat = 66
  // 选中玻璃是独立于等分 tab 槽的超宽气泡；边缘项会自然伸出 dock 外沿。
  // mini 比 dock 矮一档：dock 是导航主锚点，mini 是次级播放状态条
  // （与 Dart kChromeMiniHeight 严格同步）。
  static let miniHeight: CGFloat = 50
  static let gap: CGFloat = 8
  static let horizontalPadding: CGFloat = 16
  static let systemDockMinimumHorizontalInset: CGFloat = 20
  // 内容与 chrome 顶缘之间的呼吸距，计入回报给 Flutter 的 inset。
  static let contentClearance: CGFloat = 8

  // chrome 底缘到屏幕物理底边的距离：压进安全区、悬在 home indicator 上方
  // （对齐 Apple Music 浮动 dock），无 home indicator 的设备退到 10。
  static func bottomOffset(safeArea: CGFloat) -> CGFloat {
    max(10, safeArea - 10)
  }
}

// dock 4 tab 的 id/SF Symbol/标签，id 与 Dart kShellTabs 严格一致，
// 图标语义对齐 Flutter bottom_nav（leaderboard/library/insights/settings）。
// 搜索并入榜单页头胶囊（Dart push 全屏搜索页），不占 dock 位。
struct GlassDockTab {
  let id: String
  let symbol: String
  let label: String

  static let all: [GlassDockTab] = [
    // trophy 而非 chart.bar：后者线条版是空心方块轮廓，混在单笔画家族里突兀；
    // 奖杯与 Material leaderboard 的备选（emoji_events）同语义，笔画协调。
    GlassDockTab(id: "charts", symbol: "trophy", label: "榜单"),
    GlassDockTab(id: "playlists", symbol: "music.note.list", label: "歌单"),
    GlassDockTab(id: "stats", symbol: "chart.line.uptrend.xyaxis", label: "统计"),
    GlassDockTab(id: "settings", symbol: "gearshape", label: "设置"),
  ]
}
