import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  private var didPresentSplash = false

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    // Hinata: native Splash-Animation über dem Flutter-View starten.
    // WICHTIG: Unter Flutter 3.44 ist self.window in willConnectTo noch versteckt
    // (hidden = YES) und wird erst danach key & visible gemacht. Hängt man das
    // Overlay sofort an dieses Fenster, bleibt es unsichtbar (man sieht nur das
    // statische LaunchScreen-Storyboard). Deshalb warten wir per Runloop auf ein
    // sichtbares Fenster und präsentieren erst dann.
    presentSplashWhenWindowVisible(scene, attempt: 0)
  }

  private func presentSplashWhenWindowVisible(_ scene: UIScene, attempt: Int) {
    guard !didPresentSplash else { return }
    let windowScene = scene as? UIWindowScene
    let candidates = windowScene?.windows ?? []
    // Nur ein wirklich sichtbares Fenster akzeptieren (keyWindow allein genügt nicht –
    // es kann hidden = YES sein).
    let host = candidates.first(where: { $0.isKeyWindow && !$0.isHidden })
      ?? candidates.first(where: { !$0.isHidden })

    if let host = host {
      didPresentSplash = true
      HinataSplashView.present(in: host)
    } else if attempt < 240 {
      // Noch kein sichtbares Fenster – im nächsten Runloop-Durchlauf erneut versuchen.
      DispatchQueue.main.async { [weak self] in
        self?.presentSplashWhenWindowVisible(scene, attempt: attempt + 1)
      }
    }
  }
}
