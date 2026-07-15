import SwiftUI

// iOS 26+ 液态玻璃 dock + mini player 的 SwiftUI overlay。
// 只渲染 chrome 并回传语义 intent；不持有 token、不调 Server（docs/06 §3）。
//
// 形态对齐 Apple Music：mini player 胶囊悬浮在 dock 上方，chrome 压进底部
// 安全区、悬在 home indicator 上方；向下滚动时 dock 收成单枚当前 tab pill、
// mini 收窄，反向滚动展开。玻璃只用于这两块 chrome，内容（下层 Flutter）
// 不玻璃化（AGENTS 铁律 9）。
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

  var body: some View {
    VStack(spacing: GlassShellMetrics.gap) {
      Spacer(minLength: 0)
      if state.showMiniPlayer && state.trackId != nil {
        GlassMiniPlayer(
          state: state,
          reduceTransparency: reduceTransparency,
          onIntent: onIntent
        )
        .reportChromeFrame("mini", to: onChromeFrame)
        .transition(.move(edge: .bottom).combined(with: .opacity))
      } else {
        // 退场时归零命中区，防止残留的旧 frame 挡住 Flutter。
        Color.clear.frame(height: 0)
          .onAppear { onChromeFrame("mini", .zero) }
      }
      if state.showTabBar {
        dock
          .reportChromeFrame("dock", to: onChromeFrame)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      } else {
        Color.clear.frame(height: 0)
          .onAppear { onChromeFrame("dock", .zero) }
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

  // dock：展开 = 5 tab 等分胶囊条；收缩 = 单枚当前 tab pill 居中。
  private var dock: some View {
    HStack(spacing: 0) {
      if state.minimized {
        if let tab = GlassDockTab.all.first(where: { $0.id == state.selectedTab }) {
          DockItem(tab: tab, active: true, compact: true) {
            // 收缩态点 pill 只展开，不切 tab。
            onIntent("expand", nil)
          }
        }
      } else {
        ForEach(GlassDockTab.all, id: \.id) { tab in
          DockItem(tab: tab, active: tab.id == state.selectedTab, compact: false) {
            onIntent("selectTab", tab.id)
          }
        }
      }
    }
    .frame(height: GlassShellMetrics.dockHeight)
    .frame(maxWidth: state.minimized ? nil : .infinity)
    .glassChrome(
      capsule: true,
      reduceTransparency: reduceTransparency || state.reduceTransparency
    )
    .frame(maxWidth: .infinity, alignment: .center)
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

// 单个 dock tab：SF Symbol + 小字标签；active 用主题墨色、其余 secondary。
@available(iOS 26.0, *)
private struct DockItem: View {
  let tab: GlassDockTab
  let active: Bool
  let compact: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 3) {
        Image(systemName: tab.symbol)
          .font(.system(size: 22, weight: .medium))
        Text(tab.label)
          .font(.system(size: 11))
      }
      // 选中态只换颜色（墨 vs 灰），图标恒为线条款——与 Flutter 底栏同纪律；
      // fill 变体视觉重量参差（chart.bar.fill 尤重），不用。
      .foregroundStyle(active ? Color.primary : Color.secondary)
      .frame(maxWidth: compact ? nil : .infinity)
      .padding(.horizontal, compact ? 26 : 0)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(tab.label)
    .accessibilityAddTraits(active ? [.isSelected] : [])
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
