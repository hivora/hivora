import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    // Hivora: native Splash-Animation über dem Flutter-View starten
    if let windowScene = scene as? UIWindowScene,
       let window = windowScene.windows.first {
      HivoraSplashView.present(in: window)
    }
  }
}
