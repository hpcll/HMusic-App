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
  @Published var outputLabel: String = "未选择设备"
  // 与 Flutter 两行 mini 的排版使用同一高度和缩放字号。
  @Published var miniPlayerHeight: CGFloat = 50
  @Published var miniTitleFontSize: CGFloat = 14
  @Published var miniDetailFontSize: CGFloat = 12
  @Published var allowMinimize: Bool = false
  // Flutter 上报向下滚收起、向上滚展开；收起为左导航/中 mini/右搜索。
  @Published var minimized: Bool = false
  // Dart configure 下发的降级补充；系统开关另经 SwiftUI Environment 直接生效，
  // 二者取 or（docs/06 §3 回退策略 3/4）。
  @Published var reduceMotion: Bool = false
  @Published var reduceTransparency: Bool = false
  // 底部安全区高度，由宿主从 UIKit window 注入（overlay 压安全区定位用）。
  @Published var bottomSafeArea: CGFloat = 0
  // 当前 iOS 26+ 全部使用系统 UITabBarController，不启用旧的自绘 dock。
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
  // 两行 mini 基准高度，与 Dart kChromeMiniHeight 严格同步。
  static let miniHeight: CGFloat = 50
  static let minimumCompactMiniWidth: CGFloat = 160
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

// 四个入口的 id 与 Dart kShellTabs 一致。
struct GlassDockTab {
  let id: String
  let symbol: String
  let label: String

  static let all: [GlassDockTab] = [
    GlassDockTab(id: "charts", symbol: "flame", label: "榜单"),
    GlassDockTab(id: "playlists", symbol: "music.note.list", label: "歌单"),
    GlassDockTab(id: "stats", symbol: "chart.line.uptrend.xyaxis", label: "统计"),
    GlassDockTab(id: "settings", symbol: "gearshape", label: "设置"),
  ]
}
