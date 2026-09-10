import SwiftUI

// 系统 UIKit dock 之外的 chrome：mini、收起导航与搜索圆钮。
// frame 只用于精确触摸穿透；内容让位使用同一份稳定终态高度。
@available(iOS 26.0, *)
struct GlassShellOverlay: View {
  @ObservedObject var state: GlassShellState
  let onIntent: (String, String?) -> Void
  let onChromeFrame: (String, CGRect) -> Void

  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Namespace private var chromeSpace

  var body: some View {
    VStack(spacing: GlassShellMetrics.gap) {
      Spacer(minLength: 0)
      if state.minimized && state.showTabBar {
        HStack(spacing: GlassShellMetrics.gap) {
          compactDockSlot
          miniSlot
          searchSlot
        }
      } else {
        miniSlot
      }
    }
    .padding(.horizontal, state.systemDockHorizontalInset)
    .padding(.bottom, overlayBottomPadding)
    .ignoresSafeArea(.all, edges: .bottom)
    .animation(
      reduceMotion || state.reduceMotion
        ? nil
        : .spring(response: 0.42, dampingFraction: 0.86),
      value: animationKey
    )
  }

  private var overlayBottomPadding: CGFloat {
    if state.minimized { return state.systemDockBottomOffset }
    if state.showTabBar {
      return state.systemDockClearance + GlassShellMetrics.gap
    }
    return GlassShellMetrics.bottomOffset(safeArea: state.bottomSafeArea)
  }

  private var animationKey: String {
    "\(state.minimized)-\(state.showTabBar)-\(state.showMiniPlayer)-\(state.trackId ?? "")-\(state.selectedTab)-\(state.miniPlayerHeight)"
  }

  @ViewBuilder private var miniSlot: some View {
    if state.showTabBar && state.showMiniPlayer {
      GlassMiniPlayer(
        state: state,
        reduceTransparency: reduceTransparency,
        onIntent: onIntent
      )
      .matchedGeometryEffect(id: "mini", in: chromeSpace)
      .reportChromeFrame("mini", to: onChromeFrame)
      .transition(.move(edge: .bottom).combined(with: .opacity))
    } else {
      Color.clear.frame(height: 0)
        .onAppear { onChromeFrame("mini", .zero) }
    }
  }

  private var compactDockSlot: some View {
    Button {
      onIntent("expand", nil)
    } label: {
      Image(systemName: selectedTab.symbol)
        .font(.system(size: 22, weight: .medium))
        .foregroundStyle(Color.primary)
        .frame(width: state.miniPlayerHeight, height: state.miniPlayerHeight)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("展开导航，\(selectedTab.label)")
    .accessibilityAddTraits(.isSelected)
    .glassChrome(reduceTransparency: reduceTransparency || state.reduceTransparency)
    .matchedGeometryEffect(id: "dock", in: chromeSpace)
    .reportChromeFrame("compactDock", to: onChromeFrame)
    .onDisappear { onChromeFrame("compactDock", .zero) }
    .transition(.opacity)
  }

  private var searchSlot: some View {
    Button { onIntent("openSearch", nil) } label: {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 22, weight: .medium))
        .foregroundStyle(Color.primary)
        .frame(width: state.miniPlayerHeight, height: state.miniPlayerHeight)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("搜索")
    .glassChrome(reduceTransparency: reduceTransparency || state.reduceTransparency)
    .reportChromeFrame("search", to: onChromeFrame)
    .onDisappear { onChromeFrame("search", .zero) }
    .transition(.opacity)
  }

  private var selectedTab: GlassDockTab {
    GlassDockTab.all.first(where: { $0.id == state.selectedTab }) ?? GlassDockTab.all[0]
  }
}

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

  @ViewBuilder
  func glassChrome(reduceTransparency: Bool) -> some View {
    if reduceTransparency {
      self.background(
        Capsule(style: .continuous)
          .fill(Color(uiColor: .systemBackground))
          .overlay(
            Capsule(style: .continuous).strokeBorder(Color.primary.opacity(0.18))
          )
          .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
      )
    } else if #available(iOS 27.0, *) {
      self.glassEffect(.regular.interactive(), in: .capsule)
    } else {
      self.glassEffect(.clear.interactive(), in: .capsule)
    }
  }
}
