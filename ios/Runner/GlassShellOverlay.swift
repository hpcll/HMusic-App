import SwiftUI

// iOS 26+ 液态玻璃 dock + mini player 的 SwiftUI overlay。
// 只渲染 chrome 并回传语义 intent；不持有 token、不调 Server（docs/06 §3）。
//
// 形态对齐 Apple Music：mini player 胶囊悬浮在 dock 上方，chrome 压进底部
// 安全区、悬在 home indicator 上方；向下滚动时收缩为「mini 内联 + 当前 tab
// 图标圆钮」的等高一排，只有滚回顶部（或点圆钮/切 tab）才展开——触发语义
// 统一在 Dart ScrollMinimizeListener，此处只渲染。玻璃只用于这两块 chrome，
// 内容（下层 Flutter）不玻璃化（AGENTS 铁律 9）。
//
// onChromeFrame：dock/mini 各自把实时 frame（global 坐标）上报宿主，
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

  var body: some View {
    VStack(spacing: GlassShellMetrics.gap) {
      Spacer(minLength: 0)
      if state.minimized {
        // 收缩：mini 内联占满剩余宽度、图标圆钮贴右（无 mini 时圆钮居中）。
        HStack(spacing: GlassShellMetrics.gap) {
          miniSlot
          dockSlot
        }
      } else {
        miniSlot
        dockSlot
      }
    }
    .padding(.horizontal, GlassShellMetrics.horizontalPadding)
    .padding(
      .bottom, GlassShellMetrics.bottomOffset(safeArea: state.bottomSafeArea)
    )
    // chrome 压进系统安全区贴底（Apple Music dock 形态）。
    .ignoresSafeArea(.all, edges: .bottom)
    .animation(
      reduceMotion || state.reduceMotion
        ? nil
        : .spring(response: 0.42, dampingFraction: 0.86),
      value: animationKey
    )
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

  @ViewBuilder private var dockSlot: some View {
    if state.showTabBar {
      dock
        .matchedGeometryEffect(id: "dock", in: chromeSpace)
        .reportChromeFrame("dock", to: onChromeFrame)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    } else {
      Color.clear.frame(height: 0)
        .onAppear { onChromeFrame("dock", .zero) }
    }
  }

  // dock：展开 = 5 tab 等分胶囊条；收缩 = 当前 tab 图标圆钮，高度降到
  // mini 同档，与内联 mini 排成等高一行。
  private var dock: some View {
    HStack(spacing: 0) {
      if state.minimized {
        if let tab = GlassDockTab.all.first(where: { $0.id == state.selectedTab }) {
          DockItem(tab: tab, active: true, compact: true) {
            // 收缩态点圆钮只展开，不切 tab。
            onIntent("expand", nil)
          }
        }
      } else {
        ForEach(GlassDockTab.all, id: \.id) { tab in
          DockItem(
            tab: tab,
            active: tab.id == state.selectedTab,
            compact: false,
            namespace: chromeSpace
          ) {
            onIntent("selectTab", tab.id)
          }
        }
      }
    }
    .frame(
      height: state.minimized
        ? GlassShellMetrics.miniHeight : GlassShellMetrics.dockHeight
    )
    .frame(maxWidth: state.minimized ? nil : .infinity)
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

// 单个 dock tab：SF Symbol + 小字标签；active 用主题墨色、其余 secondary，
// 展开态选中项背后垫灰药丸，切 tab 时经 matchedGeometryEffect 从 A 滑到 B
//（对齐 Apple Music tab bar；与 Flutter 底栏 AnimatedAlign 药丸同纪律）。
// compact（收缩圆钮）只留图标，无药丸，标签语义走 accessibilityLabel。
@available(iOS 26.0, *)
private struct DockItem: View {
  let tab: GlassDockTab
  let active: Bool
  let compact: Bool
  var namespace: Namespace.ID? = nil
  let onTap: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 3) {
        Image(systemName: tab.symbol)
          .font(.system(size: 22, weight: .medium))
        if !compact {
          Text(tab.label)
            .font(.system(size: 11))
        }
      }
      // 选中态 = 灰药丸 + 换色（墨 vs 灰），图标恒为线条款；
      // fill 变体视觉重量参差（chart.bar.fill 尤重），不用。
      .foregroundStyle(active ? Color.primary : Color.secondary)
      .frame(
        maxWidth: compact ? nil : .infinity,
        maxHeight: compact ? nil : .infinity
      )
      .padding(.horizontal, compact ? 26 : 0)
      .background { selectionPill }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(tab.label)
    .accessibilityAddTraits(active ? [.isSelected] : [])
  }

  // 灰药丸只做「所在位置」提示，浓度压低（暗色略提亮）不与内容抢戏；
  // matchedGeometryEffect 挂在含内缩边距的整槽框上，滑动时内缩恒定。
  @ViewBuilder private var selectionPill: some View {
    if active, !compact, let namespace {
      Capsule(style: .continuous)
        .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.07))
        .padding(.horizontal, 5)
        .padding(.vertical, 7)
        .matchedGeometryEffect(id: "dockSelection", in: namespace)
    }
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
    } else {
      self.glassEffect(.regular.interactive(), in: .capsule)
    }
  }
}
