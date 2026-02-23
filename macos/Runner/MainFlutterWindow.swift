import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Set window size and constraints
    self.setContentSize(NSSize(width: 720, height: 680))
    self.minSize = NSSize(width: 600, height: 560)
    self.title = "APD DICOM → NIfTI Converter"

    // Center on screen
    if let screen = self.screen {
      let screenFrame = screen.visibleFrame
      let x = screenFrame.midX - 720 / 2
      let y = screenFrame.midY - 680 / 2
      self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
