import Cocoa
import FlutterMacOS

private final class PassthroughVisualEffectView: NSVisualEffectView {
  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }
}

private final class FlutterGlassContainerViewController: NSViewController {
  init(flutterViewController: FlutterViewController) {
    self.flutterViewController = flutterViewController
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  let flutterViewController: FlutterViewController

  override func loadView() {
    let containerView = NSView()
    let glassView = PassthroughVisualEffectView(frame: containerView.bounds)
    glassView.autoresizingMask = [.width, .height]
    glassView.material = .sidebar
    glassView.blendingMode = .behindWindow
    glassView.state = .followsWindowActiveState
    containerView.addSubview(glassView)

    addChild(flutterViewController)
    let flutterView = flutterViewController.view
    flutterView.frame = containerView.bounds
    flutterView.autoresizingMask = [.width, .height]
    containerView.addSubview(flutterView, positioned: .above, relativeTo: glassView)
    view = containerView
  }
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let containerViewController = FlutterGlassContainerViewController(
      flutterViewController: flutterViewController
    )
    let windowFrame = self.frame
    self.contentViewController = containerViewController
    self.setFrame(windowFrame, display: true)

    // 毛玻璃与 FlutterView 位于受支持的内容容器内；玻璃层不参与命中测试。
    self.isOpaque = false
    self.backgroundColor = .clear
    flutterViewController.backgroundColor = .clear
    self.ignoresMouseEvents = false

    // 桌面端锁定最小内容尺寸：宽度须 > 860px 断点（app_shell.dart），否则会塌成窄屏竖版 UI。
    // 取 900×600，比断点多留 40px 余量，避免在边界值反复抖动切换布局。
    self.contentMinSize = NSSize(width: 900, height: 600)

    // 默认打开尺寸兜底：显式设成 1120×720 并居中，防止 xib contentRect 被
    // FlutterViewController 覆盖后掉回 860 断点以下、开局塌成窄屏竖版 UI。
    self.setContentSize(NSSize(width: 1120, height: 720))
    self.center()

    // 隐藏系统标题栏：内容层延伸到标题栏下方，由 Flutter 用当前主题色统一绘制整窗，
    // 消除「白标题栏 + 灰内容 + 分隔线」的割裂感。红绿灯按钮仍悬浮在左上（透明标题栏）。
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    // 内容区域必须优先把鼠标事件交给 Flutter；窗口拖动保留给标题栏区域。
    self.isMovableByWindowBackground = false

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 键盘焦点必须显式交给 FlutterViewController：官方模板把它直接设为
    // contentViewController，AppKit 自然会把它接进响应链；这里为毛玻璃套了一层
    // 容器，焦点会停在窗口自身，Flutter 收不到任何按键（表现为所有输入框都打不
    // 出字，鼠标点击却正常）。注意接收键盘的是 VC 而非其 view——实测
    // FlutterView.acceptsFirstResponder == false，把 view 设为第一响应者只会
    // 静默落到窗口上。
    self.makeFirstResponder(flutterViewController)

    super.awakeFromNib()
  }

  // 窗口重新激活（切回 App、从后台唤回）时同样要把焦点还给 Flutter：焦点若
  // 落回窗口自身，输入框就再也打不出字。Flutter 内部不改这里的第一响应者
  //（它自己在 VC 内部分发焦点），所以只认「当前是不是这个 VC」即可。
  override func becomeKey() {
    super.becomeKey()
    guard
      let container = contentViewController as? FlutterGlassContainerViewController
    else { return }
    let controller = container.flutterViewController
    if firstResponder !== controller {
      makeFirstResponder(controller)
    }
  }
}
