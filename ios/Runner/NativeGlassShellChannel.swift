import Flutter
import UIKit

// HMusic iOS 平台壳通道：Dart <-> Swift 的唯一 Method/Event channel。
// Swift 只承载系统 chrome（dock/mini player），不持有 token、不调 Server、
// 不复制业务状态。Dart 下发展示状态，Swift 回传语义 intent（见 docs/06 §7 契约）。
//
// 版本门禁：iOS 26+ 才创建 GlassShellHostController 并声明 capabilities；
// 更低版本 capabilities 回空数组，Dart 侧继续用 Flutter 自绘壳，UI 不变。
final class NativeGlassShellChannel: NSObject, FlutterStreamHandler {
  private static let methodName = "com.hupc.hmusic/platform_shell"
  private static let eventName = "com.hupc.hmusic/platform_shell/events"

  private var eventSink: FlutterEventSink?
  private weak var flutterViewController: FlutterViewController?

  private var glassHost: AnyObject?

  @available(iOS 26.0, *)
  private var host: GlassShellHostController? {
    glassHost as? GlassShellHostController
  }

  static func register(with controller: FlutterViewController) {
    let instance = NativeGlassShellChannel()
    instance.flutterViewController = controller
    let methodChannel = FlutterMethodChannel(
      name: methodName,
      binaryMessenger: controller.binaryMessenger
    )
    let eventChannel = FlutterEventChannel(
      name: eventName,
      binaryMessenger: controller.binaryMessenger
    )
    methodChannel.setMethodCallHandler(instance.handle)
    eventChannel.setStreamHandler(instance)
    // channel 生命周期与 FlutterViewController 一致，静态持有防释放。
    retained = instance
  }

  private static var retained: NativeGlassShellChannel?

  // Dart -> Native：展示状态下发，全部转交 GlassShellState。
  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 26.0, *), let host = host else {
      // 低版本没有原生壳：收下所有调用保持契约兼容，不渲染任何东西。
      result(nil)
      return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "shell.configure":
      // 系统无障碍开关经 SwiftUI Environment 自动生效；Dart 下发值作补充（取 or）。
      host.state.reduceMotion = args["reduceMotion"] as? Bool ?? false
      host.state.reduceTransparency = args["reduceTransparency"] as? Bool ?? false
      result(nil)
    case "shell.updateNavigation":
      if let tab = args["selectedTab"] as? String, !tab.isEmpty {
        host.state.selectedTab = tab
      }
      result(nil)
    case "shell.updateNowPlaying":
      host.state.trackId = args["trackId"] as? String
      host.state.trackTitle = args["title"] as? String ?? ""
      host.state.trackArtist = args["artist"] as? String ?? ""
      host.state.playing = args["playing"] as? Bool ?? false
      if let raw = args["artworkUrl"] as? String, let url = URL(string: raw) {
        host.state.artworkUrl = url
      } else {
        host.state.artworkUrl = nil
      }
      host.reportInsetIfNeeded()
      result(nil)
    case "shell.updateLayout":
      host.state.showTabBar = args["showTabBar"] as? Bool ?? false
      host.state.showMiniPlayer = args["showMiniPlayer"] as? Bool ?? false
      host.reportInsetIfNeeded()
      result(nil)
    case "shell.updateScroll":
      host.state.minimized = args["minimized"] as? Bool ?? false
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    if #available(iOS 26.0, *) {
      attachHostIfNeeded()
      sendReady(capabilities: ["bottomBar", "miniPlayer"])
      host?.reportInsetIfNeeded()
    } else {
      // 低版本：无原生 chrome，Dart 侧继续用 Flutter 壳。
      sendReady(capabilities: [])
      sendLayout(bottomInset: 0)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  @available(iOS 26.0, *)
  private func attachHostIfNeeded() {
    guard glassHost == nil, let controller = flutterViewController else { return }
    let host = GlassShellHostController(
      onIntent: { [weak self] type, value in
        self?.sendIntent(type: type, value: value)
      },
      onInsetChanged: { [weak self] inset in
        self?.sendLayout(bottomInset: inset)
      }
    )
    host.attach(to: controller)
    glassHost = host
  }

  // Native -> Dart：通道就绪与能力声明。capabilities 为空表示原生不接管，
  // Dart 侧回退 Flutter 自绘壳（docs/06 §7）。
  private func sendReady(capabilities: [String]) {
    eventSink?([
      "type": "ready",
      "capabilities": capabilities,
    ])
  }

  private func sendLayout(bottomInset: CGFloat) {
    eventSink?([
      "type": "layoutChanged",
      "topInset": 0.0,
      "bottomInset": Double(bottomInset),
    ])
  }

  private func sendIntent(type: String, value: String?) {
    var payload: [String: Any] = ["type": "intent", "intent": type]
    if let value { payload["value"] = value }
    eventSink?(payload)
  }
}
