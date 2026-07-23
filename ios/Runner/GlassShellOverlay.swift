import SwiftUI

// iOS 26+ mini player 与收缩圆钮的 SwiftUI overlay；展开态 dock 由宿主中的
// UITabBarController 绘制，以获得完整系统 Liquid Glass 行为。
// 只渲染 chrome 并回传语义 intent；不持有 token、不调 Server（docs/06 §3）。
//
// 形态对齐 Apple Music：mini player 胶囊悬浮在 dock 上方，chrome 压进底部
// 安全区、悬在 home indicator 上方；向下滚动时收缩为「mini 内联 + 当前 tab
// 图标圆钮」的等高一排，只有滚回顶部（或点圆钮/切 tab）才展开——触发语义
// 统一在 Dart ScrollMinimizeListener，此处只渲染。玻璃只用于这两块 chrome，
// 内容（下层 Flutter）不玻璃化（AGENTS 铁律 9）。
//
// onChromeFrame：mini/收缩圆钮把实时 frame（global 坐标）上报宿主，
// UIKit 层据此做精确 hitTest——frame 内吃事件，frame 外穿给 Flutter。
// onGeometryChange 在动画每帧回调，命中区始终跟手，不会出现「看着在这里
// 点了没反应/点空白误触」。
@available(iOS 26.0, *)
struct GlassShellOverlay: View {
  @ObservedObject var state: GlassShellState
  let onIntent: (String, String?) -> Void
  let onChromeFrame: (String, CGRect) -> Void

  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  // 收缩/展开时 mini 与 dock 在竖排/内联两种布局间搬家，matchedGeometryEffect
  // 让同一块 chrome 连续形变过去，而不是删除+插入的硬切。
  @Namespace private var chromeSpace
  // 自绘 dock 宽度（用于按槽位定位选中气泡）与当前按压/拖动命中的槽位；
  // pressedIndex 为 nil 时气泡落在选中 tab，非 nil 时跟手到指下槽位。
  @State private var dockWidth: CGFloat = 0
  @State private var pressedIndex: Int?
  var body: some View {
    VStack(spacing: GlassShellMetrics.gap) {
      Spacer(minLength: 0)
      if state.minimized {
        // 收缩：mini 内联占满剩余宽度、图标圆钮贴右（无 mini 时圆钮居中）。
        HStack(spacing: GlassShellMetrics.gap) {
          miniSlot
          compactDockSlot
        }
      } else {
        miniSlot
        fullDockSlot
      }
    }
    .padding(.horizontal, overlayHorizontalPadding)
    .padding(.bottom, overlayBottomPadding)
    // chrome 压进系统安全区贴底（Apple Music dock 形态）。
    .ignoresSafeArea(.all, edges: .bottom)
    .animation(
      reduceMotion || state.reduceMotion
        ? nil
        : .spring(response: 0.42, dampingFraction: 0.86),
      value: animationKey
    )
  }

  private var overlayBottomPadding: CGFloat {
    if !state.usesSystemDock {
      // 自绘 dock：展开/收缩都压同一条安全区基线。
      return GlassShellMetrics.bottomOffset(safeArea: state.bottomSafeArea)
    }
    if state.minimized {
      return state.systemDockBottomOffset
    }
    if !state.showTabBar {
      return GlassShellMetrics.bottomOffset(safeArea: state.bottomSafeArea)
    }
    return state.systemDockClearance + GlassShellMetrics.gap
  }

  private var overlayHorizontalPadding: CGFloat {
    if state.usesSystemDock && state.showTabBar {
      return state.systemDockHorizontalInset
    }
    return GlassShellMetrics.horizontalPadding
  }

  // 收缩/曲目/tab/开关任一变化都驱动同一条 spring 动画。
  private var animationKey: String {
    "\(state.minimized)-\(state.showTabBar)-\(state.showMiniPlayer)-\(state.trackId ?? "")-\(state.selectedTab)"
  }

  @ViewBuilder private var miniSlot: some View {
    if state.showMiniPlayer && state.trackId != nil {
      GlassMiniPlayer(
        state: state,
        reduceTransparency: reduceTransparency,
        onIntent: onIntent
      )
      .matchedGeometryEffect(id: "mini", in: chromeSpace)
      .reportChromeFrame("mini", to: onChromeFrame)
      .transition(.move(edge: .bottom).combined(with: .opacity))
    } else {
      // 退场时归零命中区，防止残留的旧 frame 挡住 Flutter。
      Color.clear.frame(height: 0)
        .onAppear { onChromeFrame("mini", .zero) }
    }
  }

  // 自绘 dock（26.x）：5 tab 等分玻璃胶囊条，与 mini 同一套 glassChrome 材质。
  // 与 compactDock 共享 matchedGeometryEffect id，收缩/展开是连续形变。
  @ViewBuilder private var fullDockSlot: some View {
    if !state.usesSystemDock && state.showTabBar {
      fullDock
        .matchedGeometryEffect(id: "dock", in: chromeSpace)
        .reportChromeFrame("dock", to: onChromeFrame)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    } else {
      Color.clear.frame(height: 0)
        .onAppear { onChromeFrame("dock", .zero) }
    }
  }

  private var fullDock: some View {
    let tabs = GlassDockTab.all
    let selectedIndex = tabs.firstIndex { $0.id == state.selectedTab } ?? 0
    let activeIndex = min(max(pressedIndex ?? selectedIndex, 0), tabs.count - 1)
    return HStack(spacing: 0) {
      ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
        FullDockItem(tab: tab, active: index == activeIndex)
      }
    }
    .frame(height: GlassShellMetrics.dockHeight)
    .frame(maxWidth: .infinity)
    // 选中气泡：对齐系统 lens 比例（比槽位宽一圈、上下收 5），按压放大、
    // 跟手滑动，松手落位。放在 items 底下、玻璃之上。
    .background(alignment: .leading) {
      if dockWidth > 0 {
        let slot = dockWidth / CGFloat(tabs.count)
        Capsule(style: .continuous)
          .fill(Color.primary.opacity(0.08))
          .frame(
            width: slot + 8,
            height: GlassShellMetrics.dockHeight - 10
          )
          .scaleEffect(pressedIndex != nil ? 1.1 : 1)
          .offset(x: slot * CGFloat(activeIndex) - 4)
          .animation(
            reduceMotion || state.reduceMotion
              ? nil
              : .spring(response: 0.32, dampingFraction: 0.78),
            value: activeIndex
          )
          .animation(
            reduceMotion || state.reduceMotion
              ? nil
              : .spring(response: 0.32, dampingFraction: 0.78),
            value: pressedIndex != nil
          )
      }
    }
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.width
    } action: { width in
      dockWidth = width
    }
    .contentShape(Capsule(style: .continuous))
    // 按下即吸附到指下槽位，可按住横向拖动，抬手才真正切 tab——
    // 对齐系统 tab bar 的 lens 跟手交互；轻点等价于按下即抬手。
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          guard dockWidth > 0 else { return }
          let slot = dockWidth / CGFloat(tabs.count)
          pressedIndex = min(max(Int(value.location.x / slot), 0), tabs.count - 1)
        }
        .onEnded { value in
          defer { pressedIndex = nil }
          guard dockWidth > 0 else { return }
          let slot = dockWidth / CGFloat(tabs.count)
          let index = min(max(Int(value.location.x / slot), 0), tabs.count - 1)
          if tabs[index].id != state.selectedTab {
            onIntent("selectTab", tabs[index].id)
          }
        }
    )
    .glassChrome(
      capsule: true,
      reduceTransparency: reduceTransparency || state.reduceTransparency
    )
  }

  @ViewBuilder private var compactDockSlot: some View {
    if state.showTabBar && state.minimized {
      compactDock
        .matchedGeometryEffect(id: "dock", in: chromeSpace)
        .reportChromeFrame("compactDock", to: onChromeFrame)
        // 自绘 dock 与圆钮共存于 SwiftUI，matchedGeometry 直接连续形变；
        // 系统 dock 在 UIKit 里无法 matched，用「更大、贴右下」缩到位近似
        // dock 收进右下角，展开反向放大交还。
        .transition(
          state.usesSystemDock
            ? .scale(scale: 2.6, anchor: .bottomTrailing).combined(with: .opacity)
            : .opacity
        )
    } else {
      Color.clear.frame(height: 0)
        .onAppear { onChromeFrame("compactDock", .zero) }
    }
  }

  private var compactDock: some View {
    HStack(spacing: 0) {
      if let tab = GlassDockTab.all.first(where: { $0.id == state.selectedTab }) {
        CompactDockItem(tab: tab) {
          // 收缩态点圆钮只展开，不切 tab。
          onIntent("expand", nil)
        }
      }
    }
    .frame(height: GlassShellMetrics.miniHeight)
    .glassChrome(
      capsule: true,
      reduceTransparency: reduceTransparency || state.reduceTransparency
    )
  }
}

// chrome 命中区上报修饰：global frame 任意变化（含动画插值帧）都会回调。
@available(iOS 26.0, *)
extension View {
  func reportChromeFrame(
    _ id: String, to report: @escaping (String, CGRect) -> Void
  ) -> some View {
    onGeometryChange(for: CGRect.self) { proxy in
      proxy.frame(in: .global)
    } action: { frame in
      report(id, frame)
    }
  }
}

// 自绘 dock 的单个 tab：SF Symbol + 小字标签；active 用主题墨色、其余 secondary。
// 选中态只换颜色，图标恒为线条款——与 Flutter 底栏同纪律。
@available(iOS 26.0, *)
private struct FullDockItem: View {
  let tab: GlassDockTab
  let active: Bool

  // 点选由 dock 级的 DragGesture 统一处理（跟手 lens），此处只渲染图标+标签。
  var body: some View {
    VStack(spacing: 3) {
      Image(systemName: tab.symbol)
        .font(.system(size: 22, weight: .medium))
      Text(tab.label)
        .font(.system(size: 11))
    }
    .foregroundStyle(active ? Color.primary : Color.secondary)
    .frame(maxWidth: .infinity)
    .contentShape(Rectangle())
    .accessibilityElement()
    .accessibilityLabel(tab.label)
    .accessibilityAddTraits(active ? [.isSelected] : [])
  }
}

// 系统 tab bar 收缩后的本地圆钮；展开态完全交给 UIKit UITabBarController。
@available(iOS 26.0, *)
private struct CompactDockItem: View {
  let tab: GlassDockTab
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      Image(systemName: tab.symbol)
        .font(.system(size: 22, weight: .medium))
        .foregroundStyle(Color.primary)
        .frame(height: GlassShellMetrics.miniHeight)
        .padding(.horizontal, 26)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(tab.label)
    .accessibilityAddTraits(.isSelected)
  }
}

// 玻璃 chrome 共用修饰：iOS 26 glassEffect；「降低透明度」时换高对比不透明底
// （docs/06 §3 回退策略 3）。
@available(iOS 26.0, *)
extension View {
  @ViewBuilder
  func glassChrome(capsule: Bool, reduceTransparency: Bool) -> some View {
    if reduceTransparency {
      self
        .background(
          Capsule(style: .continuous)
            .fill(Color(uiColor: .systemBackground))
            .overlay(
              Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.18))
            )
            .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
        )
    } else if #available(iOS 27.0, *) {
      self.glassEffect(.regular.interactive(), in: .capsule)
    } else {
      // iOS 26.x 的 .regular 偏磨砂，与 UIKit 系统 dock 的透亮玻璃不同风格；
      // 换 .clear 靠齐。27 起 .regular 与系统 bar 观感一致，维持原状。
      self.glassEffect(.clear.interactive(), in: .capsule)
    }
  }
}
