import Flutter
import UIKit

// HMusic iOS 平台壳通道：Dart <-> Swift 的唯一 Method/Event channel。
// Swift 只承载系统 chrome（顶栏/底栏/mini player/控制面板），不持有 token、不调 Server、
// 不复制业务状态。Dart 下发展示状态，Swift 回传语义 intent（见 docs/06 §7 契约）。
final class NativeGlassShellChannel: NSObject, FlutterStreamHandler {
  private static let methodName = "com.hupc.hmusic/platform_shell"
  private static let eventName = "com.hupc.hmusic/platform_shell/events"

  private var eventSink: FlutterEventSink?

  static func register(with messenger: FlutterBinaryMessenger) {
    let instance = NativeGlassShellChannel()
    let methodChannel = FlutterMethodChannel(
      name: methodName,
      binaryMessenger: messenger
    )
    let eventChannel = FlutterEventChannel(
      name: eventName,
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler(instance.handle)
    eventChannel.setStreamHandler(instance)
  }

  // Dart -> Native：展示状态下发。P0 阶段先收下不渲染玻璃，
  // 真实 SwiftUI overlay 在 iOS 27 真机 spike 阶段接入。
  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "shell.configure":
      result(nil)
    case "shell.updateNavigation":
      result(nil)
    case "shell.updateNowPlaying":
      result(nil)
    case "shell.updateLayout":
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
    sendReady()
    sendCurrentLayout()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  // Native -> Dart：通道就绪与能力声明。capabilities 列出当前可渲染的 chrome 元素，
  // 让 Dart 侧决定是否回退到 AdaptiveGlassShell（docs/06 §7）。
  private func sendReady() {
    eventSink?([
      "type": "ready",
      "capabilities": ["topBar", "bottomBar", "miniPlayer"],
    ])
  }

  private func sendCurrentLayout() {
    // P0 占位 inset：真实安全区由 SwiftUI overlay 在真机阶段按窗口/设备回报。
    eventSink?([
      "type": "layoutChanged",
      "topInset": 0.0,
      "bottomInset": 0.0,
    ])
  }
}
