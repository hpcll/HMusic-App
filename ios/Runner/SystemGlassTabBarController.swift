import UIKit

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
final class SystemGlassTabBarController: UITabBarController,
  UITabBarControllerDelegate
{
  private let onSelect: (String) -> Void
  private let onFrame: (CGRect, CGRect) -> Void
  private var applyingState = false

  init(onSelect: @escaping (String) -> Void, onFrame: @escaping (CGRect, CGRect) -> Void) {
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
    // 滚动收起对齐 Apple Music（docs/06）：下滚时系统把 dock 收成小胶囊，
    // platter frame / chrome insets 会经 onGeometryChange / layoutChanged
    // 照常上报，Flutter 内容 inset 跟随系统行为。若与 mini 胶囊布局冲突，
    // 回退 .never 并在 docs/06 记录原因。
    tabBarMinimizeBehavior = .onScrollDown
    // iOS 26 Liquid Glass 忽略 unselectedItemTintColor，未选中会跟选中一样深。
    // 用 alwaysOriginal 烤 textStrong/muted（对齐 Flutter AppBottomNav）。
    // 关键约束：
    // 1) SF Symbol 钉死 pointSize 22（见 tabSymbol），与 SwiftUI overlay 同尺寸；
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

  // 钉死 pointSize 22 对齐 GlassShellOverlay 的 .font(.system(size: 22))——
  // 两条原生路径同尺寸，否则系统默认尺寸跟 Dynamic Type 浮动，26+ 原生壳
  // 会比 Flutter 回退壳明显大一圈。
  // 注意 Flutter 侧写的是 kDockIconSize = 28 而非 22：那是字形框尺寸，与本处
  // 的渲染点尺寸不是同一个量，两边墨迹都落在 ~22.5pt（见 bottom_nav.dart 注释）。
  // scale .medium 保持字形在 22pt 画布内的比例，不额外放大 intrinsic size：
  // 历史上把标题挤出 floating glass 的是自定义画布/更大 pointSize，不是本配置。
  private static let symbolConfig = UIImage.SymbolConfiguration(
    pointSize: 22,
    weight: .medium,
    scale: .medium
  )

  private static func tabSymbol(_ name: String, color: UIColor) -> UIImage? {
    UIImage(systemName: name, withConfiguration: symbolConfig)?
      .withTintColor(color, renderingMode: .alwaysOriginal)
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

  // 上报两路 frame：
  // - tabBar 整框（公开 API，任何系统版本都覆盖全部 tab 按钮）→ 命中区。
  //   触摸能不能点进 dock 只允许依赖稳定接口；下面的 platter 探测在任何
  //   系统版本都只许影响视觉几何，不许影响命中。
  // - 浮动 platter（可见玻璃台面）→ mini/收缩圆钮贴齐的几何基线。
  //   iOS 26 的 tabBar bounds 含 home indicator 安全区，platter 才是可见
  //   部分；iOS 27 起内部子视图结构可能再变，探测失败退回 tabBar 整框，
  //   代价只是 bottomOffset 多算一条安全区（视觉），命中不受影响。
  private func reportTabBarFrame() {
    guard !isTabBarHidden else {
      onFrame(.zero, .zero)
      return
    }
    guard let window = view.window else { return }
    let platter = tabBar.subviews.first { subview in
      let frame = subview.frame
      return frame.minY <= 0.5
        && frame.width < tabBar.bounds.width
        && frame.height > 0
        && frame.height < tabBar.bounds.height
    } ?? tabBar
    onFrame(
      platter.convert(platter.bounds, to: window),
      tabBar.convert(tabBar.bounds, to: window)
    )
  }

  func apply(selectedTab id: String, visible: Bool, reduceMotion: Bool, allowMinimize: Bool) {
    tabBarMinimizeBehavior = allowMinimize ? .onScrollDown : .never
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
