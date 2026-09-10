import SwiftUI
import UIKit

// 玻璃壳宿主：把 SwiftUI overlay 挂在 FlutterViewController 上层，
// 并解决两件 UIKit 层面的事——
// 1. 触摸穿透：SwiftUI 经 PreferenceKey 上报 chrome（dock/mini）实际 frame，
//    hitTest 只在 frame 内吃事件，其余全部穿给 Flutter；
// 2. inset 回报：chrome 占位高度变化时通知 Dart，内容滚动区让位。
@available(iOS 26.0, *)
final class GlassShellHostController {
  let state = GlassShellState()

  private weak var flutterViewController: UIViewController?
  private var hosting: UIHostingController<AnyView>?
  private var systemTabs: SystemGlassTabBarController?
  private var overlayPassthrough: PassthroughView?
  private var tabsPassthrough: PassthroughView?
  private var lastReportedInset: CGFloat = -1
  private let onIntent: (String, String?) -> Void
  private let onInsetChanged: (CGFloat) -> Void

  init(
    onIntent: @escaping (String, String?) -> Void,
    onInsetChanged: @escaping (CGFloat) -> Void
  ) {
    self.onIntent = onIntent
    self.onInsetChanged = onInsetChanged
  }

  func attach(to flutterViewController: UIViewController) {
    guard hosting == nil else { return }
    self.flutterViewController = flutterViewController

    // 全版本都挂系统 tab bar：只有 UIKit 能给出原生 lens 选中态与长按跟手，
    // 自绘无法 1:1 复刻。材质必须留给系统默认 Liquid Glass——不要写
    // standardAppearance / 背景相关属性（Apple 文档：自定义 appearance 会
    // 盖掉或干扰系统玻璃，相册/Apple Music 也不自定义 bar 背景）。
    let useSystemDock = true
    state.usesSystemDock = useSystemDock

    let overlayPassthrough = PassthroughView()
    let overlay = GlassShellOverlay(
      state: state,
      onIntent: { [weak self] type, value in
        self?.handleOverlayIntent(type: type, value: value)
      },
      onChromeFrame: { [weak overlayPassthrough] id, frame in
        overlayPassthrough?.setInteractiveFrame(frame, for: id)
      }
    )
    let hosting = UIHostingController(rootView: AnyView(overlay))
    hosting.view.backgroundColor = .clear
    overlayPassthrough.translatesAutoresizingMaskIntoConstraints = false
    hosting.view.translatesAutoresizingMaskIntoConstraints = false

    if useSystemDock {
      attachSystemDock(to: flutterViewController)
    }

    installChild(hosting, in: overlayPassthrough, parent: flutterViewController)
    constrainChild(hosting, in: overlayPassthrough, parent: flutterViewController)
    hosting.didMove(toParent: flutterViewController)
    self.hosting = hosting
    self.overlayPassthrough = overlayPassthrough
    syncSafeArea()
    syncSystemTabBar()
  }

  private func attachSystemDock(to parent: UIViewController) {
    let passthrough = PassthroughView()
    let tabs = SystemGlassTabBarController(
      onSelect: { [weak self] tab in
        self?.onIntent("selectTab", tab)
      },
      // 命中使用公开 tabBar 整框；platter 只作视觉几何，不能决定按钮可否点击。
      // 两个宿主都铺满 window，仍显式转换回本层坐标。
      onFrame: { [weak self, weak passthrough] platterFrame, tabBarFrame in
        guard let passthrough else { return }
        let localPlatter = passthrough.convert(platterFrame, from: nil)
        let localTabBar = passthrough.convert(tabBarFrame, from: nil)
        passthrough.setInteractiveFrame(localTabBar, for: "systemDock")
        self?.handleSystemDockFrame(localPlatter)
      }
    )
    tabs.view.backgroundColor = .clear
    passthrough.translatesAutoresizingMaskIntoConstraints = false
    tabs.view.translatesAutoresizingMaskIntoConstraints = false
    installChild(tabs, in: passthrough, parent: parent)
    tabs.didMove(toParent: parent)
    constrainChild(tabs, in: passthrough, parent: parent)
    systemTabs = tabs
    tabsPassthrough = passthrough
  }

  private func installChild(
    _ child: UIViewController, in container: PassthroughView, parent: UIViewController
  ) {
    parent.addChild(child)
    container.addSubview(child.view)
    parent.view.addSubview(container)
  }

  private func constrainChild(
    _ child: UIViewController, in container: PassthroughView, parent: UIViewController
  ) {
    // 宿主必须接收完整窗口边界。UIKit 自行应用底部安全区，不能再以 safeArea 截短。
    NSLayoutConstraint.activate([
      container.leadingAnchor.constraint(equalTo: parent.view.leadingAnchor),
      container.trailingAnchor.constraint(equalTo: parent.view.trailingAnchor),
      container.topAnchor.constraint(equalTo: parent.view.topAnchor),
      container.bottomAnchor.constraint(equalTo: parent.view.bottomAnchor),
      child.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      child.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      child.view.topAnchor.constraint(equalTo: container.topAnchor),
      child.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
    ])
  }

  // 把 window 安全区注入 SwiftUI 状态（overlay 压安全区定位要用）。
  func syncSafeArea() {
    let bottom = flutterViewController?.view.window?.safeAreaInsets.bottom
      ?? flutterViewController?.view.safeAreaInsets.bottom ?? 0
    if state.bottomSafeArea != bottom {
      state.bottomSafeArea = bottom
    }
  }

  // chrome 展示状态变化后重算占位高度并回报 Dart（去重）。
  // 高度按几何常量计算而非视图实测：SwiftUI 过渡动画中 frame 是插值中间态，
  // 常量算出的终态才是内容该让出的稳定 inset。
  func reportInsetIfNeeded() {
    syncSafeArea()
    var inset: CGFloat = 0
    if state.showTabBar {
      if state.usesSystemDock {
        inset += state.minimized
          ? state.systemDockBottomOffset + state.miniPlayerHeight
          : state.systemDockClearance
      } else {
        // 自绘 dock：几何全部来自本地常量，不依赖系统 bar 回报。
        inset += GlassShellMetrics.bottomOffset(safeArea: state.bottomSafeArea)
        inset += state.minimized
          ? state.miniPlayerHeight
          : GlassShellMetrics.dockHeight
      }
      if !state.minimized && state.showMiniPlayer {
        inset += state.miniPlayerHeight + GlassShellMetrics.gap
      }
      inset += GlassShellMetrics.contentClearance
    }
    guard inset != lastReportedInset else { return }
    lastReportedInset = inset
    onInsetChanged(inset)
  }

  func syncSystemTabBar() {
    if state.minimized && !canMinimize {
      state.minimized = false
      onIntent("expandDock", nil)
    }
    systemTabs?.apply(
      selectedTab: state.selectedTab,
      visible: state.showTabBar && !state.minimized,
      reduceMotion: state.reduceMotion,
      allowMinimize: canMinimize
    )
  }

  // 系统 dock 的边距可能更大，按两侧等高圆钮再校验中央 mini 的可用宽度。
  private var canMinimize: Bool {
    let width = flutterViewController?.view.bounds.width ?? 0
    let miniWidth = width - 2 * state.systemDockHorizontalInset
      - 2 * (state.miniPlayerHeight + GlassShellMetrics.gap)
    return state.showMiniPlayer && state.allowMinimize
      && miniWidth >= GlassShellMetrics.minimumCompactMiniWidth
  }

  private func handleOverlayIntent(type: String, value: String?) {
    if type == "expand" {
      // 收缩态点 pill：本地立即展开保证跟手，同时回传 expandDock 让 Dart
      // 复位滚动去重基线——否则 Dart 仍认为「已收缩」，下一次下滑被去重
      // 拦截，dock 永远收不回去。
      state.minimized = false
      syncSystemTabBar()
      reportInsetIfNeeded()
      onIntent("expandDock", nil)
      return
    }
    onIntent(type, value)
  }

  private func handleSystemDockFrame(_ frame: CGRect) {
    guard !frame.isEmpty, let passthrough = tabsPassthrough else { return }
    let clearance = max(0, passthrough.bounds.maxY - frame.minY)
    let bottomOffset = max(0, passthrough.bounds.maxY - frame.maxY)
    let horizontalInset = max(
      GlassShellMetrics.systemDockMinimumHorizontalInset,
      max(frame.minX, passthrough.bounds.maxX - frame.maxX)
    )
    var geometryChanged = false
    if abs(state.systemDockHorizontalInset - horizontalInset) > 0.5 {
      state.systemDockHorizontalInset = horizontalInset
      geometryChanged = true
    }
    if abs(state.systemDockClearance - clearance) > 0.5 {
      state.systemDockClearance = clearance
      geometryChanged = true
    }
    if abs(state.systemDockBottomOffset - bottomOffset) > 0.5 {
      state.systemDockBottomOffset = bottomOffset
      geometryChanged = true
    }
    if geometryChanged {
      if state.minimized && !canMinimize {
        syncSystemTabBar()
      }
      reportInsetIfNeeded()
    }
  }
}

// 按 chrome 实际 frame 判定的穿透容器：frame 内交给 SwiftUI 命中链，
// frame 外返回 nil 让事件落到下层 FlutterView。
// overlay 铺满全屏，SwiftUI global 坐标与本视图坐标一致，无需换算。
private final class PassthroughView: UIView {
  private var frames: [String: CGRect] = [:]

  func setInteractiveFrame(_ frame: CGRect, for id: String) {
    frames[id] = frame
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard frames.values.contains(where: { $0.contains(point) }) else {
      return nil
    }
    return super.hitTest(point, with: event)
  }
}
