import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

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
    self.isMovableByWindowBackground = true

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
