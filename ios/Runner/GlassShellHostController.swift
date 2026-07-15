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
  private var passthrough: PassthroughView?
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

    let passthrough = PassthroughView()
    let overlay = GlassShellOverlay(
      state: state,
      onIntent: { [weak self] type, value in
        self?.handleOverlayIntent(type: type, value: value)
      },
      onChromeFrame: { [weak passthrough] id, frame in
        passthrough?.setInteractiveFrame(frame, for: id)
      }
    )
    let hosting = UIHostingController(rootView: AnyView(overlay))
    hosting.view.backgroundColor = .clear
    passthrough.translatesAutoresizingMaskIntoConstraints = false
    hosting.view.translatesAutoresizingMaskIntoConstraints = false

    flutterViewController.addChild(hosting)
    passthrough.addSubview(hosting.view)
    flutterViewController.view.addSubview(passthrough)
    NSLayoutConstraint.activate([
      passthrough.leadingAnchor.constraint(
        equalTo: flutterViewController.view.leadingAnchor),
      passthrough.trailingAnchor.constraint(
        equalTo: flutterViewController.view.trailingAnchor),
      passthrough.topAnchor.constraint(equalTo: flutterViewController.view.topAnchor),
      passthrough.bottomAnchor.constraint(
        equalTo: flutterViewController.view.bottomAnchor),
      hosting.view.leadingAnchor.constraint(equalTo: passthrough.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: passthrough.trailingAnchor),
      hosting.view.topAnchor.constraint(equalTo: passthrough.topAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: passthrough.bottomAnchor),
    ])
    hosting.didMove(toParent: flutterViewController)
    self.hosting = hosting
    self.passthrough = passthrough
    syncSafeArea()
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
      inset += GlassShellMetrics.bottomOffset(safeArea: state.bottomSafeArea)
      inset += GlassShellMetrics.dockHeight
      if state.showMiniPlayer && state.trackId != nil {
        inset += GlassShellMetrics.miniHeight + GlassShellMetrics.gap
      }
      inset += GlassShellMetrics.contentClearance
    }
    guard inset != lastReportedInset else { return }
    lastReportedInset = inset
    onInsetChanged(inset)
  }

  private func handleOverlayIntent(type: String, value: String?) {
    if type == "expand" {
      // 收缩态点 pill：本地展开即可，不需要 Dart 参与。
      state.minimized = false
      return
    }
    onIntent(type, value)
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
