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
      let tabsPassthrough = PassthroughView()
      let systemTabs = SystemGlassTabBarController(
        onSelect: { [weak self] tab in
          self?.onIntent("selectTab", tab)
        },
        // systemTabs 与命中层都铺满 window；仍统一把系统回报的 window 坐标
        // 转成本层坐标，避免首次布局和收缩态混用两个原点。
        onFrame: { [weak self, weak tabsPassthrough] windowFrame in
          guard let tabsPassthrough else { return }
          let localFrame = tabsPassthrough.convert(windowFrame, from: nil)
          tabsPassthrough.setInteractiveFrame(localFrame, for: "systemDock")
          self?.handleSystemDockFrame(localFrame)
        }
      )
      systemTabs.view.backgroundColor = .clear
      tabsPassthrough.translatesAutoresizingMaskIntoConstraints = false
      systemTabs.view.translatesAutoresizingMaskIntoConstraints = false
      flutterViewController.addChild(systemTabs)
      tabsPassthrough.addSubview(systemTabs.view)
      flutterViewController.view.addSubview(tabsPassthrough)
      systemTabs.didMove(toParent: flutterViewController)
      NSLayoutConstraint.activate([
        tabsPassthrough.leadingAnchor.constraint(
          equalTo: flutterViewController.view.leadingAnchor),
        tabsPassthrough.trailingAnchor.constraint(
          equalTo: flutterViewController.view.trailingAnchor),
        tabsPassthrough.topAnchor.constraint(equalTo: flutterViewController.view.topAnchor),
        tabsPassthrough.bottomAnchor.constraint(
          equalTo: flutterViewController.view.bottomAnchor),
        systemTabs.view.leadingAnchor.constraint(equalTo: tabsPassthrough.leadingAnchor),
        systemTabs.view.trailingAnchor.constraint(equalTo: tabsPassthrough.trailingAnchor),
        systemTabs.view.topAnchor.constraint(equalTo: tabsPassthrough.topAnchor),
        // UITabBarController must receive the full window bounds. UIKit applies
        // the bottom safe area itself; ending this view at the safe-area edge
        // double-insets its floating bar and clips the tab-title layout.
        systemTabs.view.bottomAnchor.constraint(
          equalTo: tabsPassthrough.bottomAnchor),
      ])
      self.systemTabs = systemTabs
      self.tabsPassthrough = tabsPassthrough
    }

    flutterViewController.addChild(hosting)
    overlayPassthrough.addSubview(hosting.view)
    flutterViewController.view.addSubview(overlayPassthrough)
    NSLayoutConstraint.activate([
      overlayPassthrough.leadingAnchor.constraint(
        equalTo: flutterViewController.view.leadingAnchor),
      overlayPassthrough.trailingAnchor.constraint(
        equalTo: flutterViewController.view.trailingAnchor),
      overlayPassthrough.topAnchor.constraint(
        equalTo: flutterViewController.view.topAnchor),
      overlayPassthrough.bottomAnchor.constraint(
        equalTo: flutterViewController.view.bottomAnchor),
      hosting.view.leadingAnchor.constraint(equalTo: overlayPassthrough.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: overlayPassthrough.trailingAnchor),
      hosting.view.topAnchor.constraint(equalTo: overlayPassthrough.topAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: overlayPassthrough.bottomAnchor),
    ])
    hosting.didMove(toParent: flutterViewController)
    self.hosting = hosting
    self.overlayPassthrough = overlayPassthrough
    syncSafeArea()
    syncSystemTabBar()
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
          ? state.systemDockBottomOffset + GlassShellMetrics.miniHeight
          : state.systemDockClearance
      } else {
        // 自绘 dock：几何全部来自本地常量，不依赖系统 bar 回报。
        inset += GlassShellMetrics.bottomOffset(safeArea: state.bottomSafeArea)
        inset += state.minimized
          ? GlassShellMetrics.miniHeight
          : GlassShellMetrics.dockHeight
      }
      if !state.minimized && state.showMiniPlayer && state.trackId != nil {
        inset += GlassShellMetrics.miniHeight + GlassShellMetrics.gap
      }
      inset += GlassShellMetrics.contentClearance
    }
    guard inset != lastReportedInset else { return }
    lastReportedInset = inset
    onInsetChanged(inset)
  }

  func syncSystemTabBar() {
    systemTabs?.apply(
      selectedTab: state.selectedTab,
      visible: state.showTabBar && !state.minimized,
      reduceMotion: state.reduceMotion
    )
  }

  private func handleOverlayIntent(type: String, value: String?) {
    if type == "expand" {
      // 收缩态点 pill：本地立即展开保证跟手，同时回传 expandDock 让 Dart
      // 复位滚动去重基线——否则 Dart 仍认为「已收缩」，下一次下滑被去重
      // 拦截，dock 永远收不回去。
      state.minimized = false
      syncSystemTabBar()
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
      reportInsetIfNeeded()
    }
  }
}

// dock 选中/未选中色：与 Flutter HMusicPalette / AppBottomNav 对齐
// （textStrong / muted），随系统深浅色切换，避免系统 secondaryLabel 过淡。
private enum HMusicChromeColor {
  static let textStrong = UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0xF0 / 255, green: 0xF0 / 255, blue: 0xF2 / 255, alpha: 1)
      : UIColor(red: 0x1A / 255, green: 0x1A / 255, blue: 0x1A / 255, alpha: 1)
  }
  static let muted = UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0x85 / 255, green: 0x85 / 255, blue: 0x8A / 255, alpha: 1)
      : UIColor(red: 0x99 / 255, green: 0x99 / 255, blue: 0x99 / 255, alpha: 1)
  }
}

// 真正的系统 tab bar：布局、Liquid Glass 选中态、按住滑动和系统动效全部交给 UIKit。
// 子控制器保持透明，业务内容仍由下层 Flutter 绘制；代理只回传 tab id。
@available(iOS 26.0, *)
private final class SystemGlassTabBarController: UITabBarController,
  UITabBarControllerDelegate
{
  private let onSelect: (String) -> Void
  private let onFrame: (CGRect) -> Void
  private var applyingState = false

  init(onSelect: @escaping (String) -> Void, onFrame: @escaping (CGRect) -> Void) {
    self.onSelect = onSelect
    self.onFrame = onFrame
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  /// 图标色是否已按当前深浅色写入 items（只烤一次，避免 layout 重刷打乱排版）。
  private var bakedStyleTag: String = ""

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    mode = .tabBar
    tabBarMinimizeBehavior = .never
    // iOS 26 Liquid Glass 忽略 unselectedItemTintColor，未选中会跟选中一样深。
    // 用 alwaysOriginal 烤 textStrong/muted（对齐 Flutter AppBottomNav）。
    // 关键约束：
    // 1) 用系统默认 SF Symbol 尺寸（不设 pointSize），保留 tab 布局度量；
    // 2) image / selectedImage 只在 items 齐套或深浅色切换时写一次，
    //    绝不在 viewDidLayoutSubviews 每帧重烤——那会把标题挤出胶囊。
    tabBar.isTranslucent = true
    tabBar.tintColor = HMusicChromeColor.textStrong
    tabBar.unselectedItemTintColor = HMusicChromeColor.muted
    tabs = GlassDockTab.all.map { item in
      let tab = UITab(
        title: item.label,
        image: Self.tabSymbol(item.symbol, color: HMusicChromeColor.muted),
        identifier: item.id
      ) { _ in
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
      }
      tab.preferredPlacement = .fixed
      return tab
    }
    // 预热全部 VC，让 tabBar.items 一次齐，烤色覆盖全部 tab。
    for tab in tabs {
      _ = tab.viewController
    }
    // tabs 赋值会让系统自动选中第一项；此后再挂代理，避免把初始化选择
    // 误报成用户 intent，抢走 Flutter 当前路由。
    delegate = self
    bakeTabColorsIfNeeded(force: true)
  }

  // 默认 SF Symbol（无自定义 configuration）+ alwaysOriginal。
  // 自定义 pointSize/画布会改变 intrinsic size，标题被挤出 floating glass。
  private static func tabSymbol(_ name: String, color: UIColor) -> UIImage? {
    UIImage(systemName: name)?.withTintColor(color, renderingMode: .alwaysOriginal)
  }

  private func bakeTabColorsIfNeeded(force: Bool = false) {
    let styleTag = traitCollection.userInterfaceStyle == .dark ? "d" : "l"
    let itemCount = tabBar.items?.count ?? 0
    let defs = GlassDockTab.all
    if !force, bakedStyleTag == styleTag, itemCount == defs.count {
      return
    }

    let traits = traitCollection
    let active = HMusicChromeColor.textStrong.resolvedColor(with: traits)
    let inactive = HMusicChromeColor.muted.resolvedColor(with: traits)

    // 材质：不碰 standardAppearance / scrollEdgeAppearance / background*。
    tabBar.isTranslucent = true
    tabBar.tintColor = active
    tabBar.unselectedItemTintColor = inactive

    // 标题色不写 textAttributes（会扰 floating bar 布局）；图标靠 image 对。
    if tabs.count == defs.count {
      for (tab, def) in zip(tabs, defs) {
        tab.image = Self.tabSymbol(def.symbol, color: inactive)
      }
    }
    guard let items = tabBar.items, items.count == defs.count else {
      // items 未齐：等 layout 再试一次。
      bakedStyleTag = ""
      return
    }
    for (item, def) in zip(items, defs) {
      item.image = Self.tabSymbol(def.symbol, color: inactive)
      item.selectedImage = Self.tabSymbol(def.symbol, color: active)
    }
    bakedStyleTag = styleTag
    flushItemLayoutAfterBake()
  }

  // 实测：换 image 后 iOS 26 floating bar 不重排旧 item，未选中标签下坠贴底；
  // 但被「点过」（选中再离开）的 tab 会重建、恢复正常。这里程序化等价点一遍：
  // 静默把 selectedTab 遍历一圈再复位，逼系统按新图标重建每个 item 的排版。
  private func flushItemLayoutAfterBake() {
    guard let restore = selectedTab else { return }
    applyingState = true
    for tab in tabs where tab !== restore {
      selectedTab = tab
      // 同一 runloop 连续赋值可能被合并；逐个强制布局落地状态翻转。
      tabBar.layoutIfNeeded()
    }
    selectedTab = restore
    tabBar.layoutIfNeeded()
    DispatchQueue.main.async { [weak self] in
      self?.applyingState = false
    }
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
      bakeTabColorsIfNeeded(force: true)
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    // 仅 items 首次齐套时补烤；已烤过则只报 frame，避免重写 image 打乱排版。
    if bakedStyleTag.isEmpty {
      bakeTabColorsIfNeeded()
    }
    reportTabBarFrame()
  }

  private func reportTabBarFrame() {
    guard !isTabBarHidden else {
      onFrame(.zero)
      return
    }
    guard let window = view.window else { return }
    // On iOS 26 the tab bar's bounds include the home-indicator safe area,
    // while the floating platter is the visible/tappable chrome. Use that
    // platter for the compact overlay's bottom edge; fall back to the public
    // tab bar frame if UIKit changes the internal hierarchy.
    let source = tabBar.subviews.first { subview in
      let frame = subview.frame
      return frame.minY <= 0.5
        && frame.width < tabBar.bounds.width
        && frame.height > 0
        && frame.height < tabBar.bounds.height
    } ?? tabBar
    onFrame(source.convert(source.bounds, to: window))
  }

  func apply(selectedTab id: String, visible: Bool, reduceMotion: Bool) {
    if isTabBarHidden == visible {
      setTabBarHidden(!visible, animated: !reduceMotion)
    }
    if let tab = tab(forIdentifier: id), selectedTab !== tab {
      applyingState = true
      selectedTab = tab
      // UIKit 可能把程序化选择的代理回调推迟到本轮主队列末尾；延后一拍
      // 再开放用户 intent，保证 Dart 下发状态不会反向触发导航。
      DispatchQueue.main.async { [weak self] in
        self?.applyingState = false
      }
    }
    view.setNeedsLayout()
    // UITabBarController 可能在第一次状态更新后才解析出最终系统 bar frame；
    // 主队列下一拍主动回报，不能等用户点 tab 才触发布局。
    // 图标色已在 items 齐套时烤死，选中切换不再重写 image（防布局抖动）。
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.view.layoutIfNeeded()
      self.reportTabBarFrame()
    }
  }

  func tabBarController(
    _ tabBarController: UITabBarController,
    didSelectTab selectedTab: UITab,
    previousTab: UITab?
  ) {
    guard !applyingState else { return }
    onSelect(selectedTab.identifier)
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
