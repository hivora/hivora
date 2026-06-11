import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Hivora: native Splash-Animation über dem Flutter-View
    HivoraSplashView.present(over: flutterViewController.view)

    super.awakeFromNib()
  }
}
