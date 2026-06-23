import UIKit

/// Hinata native Splash-Animation (Core Animation, kein Flutter-Frame nötig).
/// Choreografie identisch zu Android (AVD) und Web (CSS):
///   0.10s  Hexagon zeichnet sich auf      (0.62s, fast-out-slow-in)
///   0.50s  Querbalken zieht durch          (0.38s)
///   0.62s  weicher Pop 0.94 -> 1.0         (Spring)
///   0.88s  Wortmarke steigt auf            (0.55s)
///   1.90s  Overlay blendet aus und entfernt sich selbst
final class HinataSplashView: UIView {

    // MARK: - Public

    /// Über dem Flutter-View einblenden. Aufruf in SceneDelegate / AppDelegate.
    static func present(in window: UIWindow) {
        let splash = HinataSplashView(frame: window.bounds)
        splash.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(splash)
        splash.start()
    }

    // MARK: - Layers

    private let markContainer = CALayer()
    private let hexLayer = CAShapeLayer()
    private let barLayer = CAShapeLayer()
    private let wordmark = UILabel()

    private var isDark: Bool {
        traitCollection.userInterfaceStyle == .dark
    }
    private var markColor: UIColor {
        UIColor(red: 0.851, green: 0.627, blue: 0.196, alpha: 1) // #D9A032 honey-amber
    }
    private var bgColor: UIColor {
        isDark ? UIColor(red: 0.075, green: 0.067, blue: 0.098, alpha: 1) // #131119
               : UIColor(red: 0.957, green: 0.953, blue: 0.937, alpha: 1) // #F4F3EF
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = bgColor

        for layer in [hexLayer, barLayer] {
            layer.fillColor = nil
            layer.strokeColor = markColor.cgColor
            layer.lineCap = .round
            layer.lineJoin = .round
            layer.strokeEnd = 0
            markContainer.addSublayer(layer)
        }
        self.layer.addSublayer(markContainer)

        wordmark.attributedText = NSAttributedString(
            string: "hinata",
            attributes: [.kern: -0.03 * 34]
        )
        wordmark.textColor = markColor
        wordmark.alpha = 0
        addSubview(wordmark)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Layout (responsiv: Logo = 30 % der kleineren Viewport-Kante)

    override func layoutSubviews() {
        super.layoutSubviews()
        let m = min(bounds.width, bounds.height)
        let markSize = m * 0.30
        let gap = m * 0.06
        let fontSize = m * 0.095

        wordmark.font = Self.soraFont(size: fontSize)
        wordmark.attributedText = NSAttributedString(
            string: "hinata",
            attributes: [.kern: -0.03 * fontSize]
        )
        wordmark.sizeToFit()

        let totalH = markSize + gap + wordmark.bounds.height
        let topY = (bounds.height - totalH) / 2

        markContainer.frame = CGRect(
            x: (bounds.width - markSize) / 2,
            y: topY,
            width: markSize,
            height: markSize
        )
        wordmark.frame.origin = CGPoint(
            x: (bounds.width - wordmark.bounds.width) / 2,
            y: topY + markSize + gap
        )

        // Pfade aus dem 120-Einheiten-Designraum skalieren
        let s = markSize / 120.0
        let hex = UIBezierPath()
        hex.move(to: CGPoint(x: 60 * s, y: 14 * s))
        hex.addLine(to: CGPoint(x: 99.8 * s, y: 37 * s))
        hex.addLine(to: CGPoint(x: 99.8 * s, y: 83 * s))
        hex.addLine(to: CGPoint(x: 60 * s, y: 106 * s))
        hex.addLine(to: CGPoint(x: 20.2 * s, y: 83 * s))
        hex.addLine(to: CGPoint(x: 20.2 * s, y: 37 * s))
        hex.close()

        let bar = UIBezierPath()
        bar.move(to: CGPoint(x: 20.2 * s, y: 60 * s))
        bar.addLine(to: CGPoint(x: 99.8 * s, y: 60 * s))

        for layer in [hexLayer, barLayer] {
            layer.frame = markContainer.bounds
            layer.lineWidth = 11 * s
        }
        hexLayer.path = hex.cgPath
        barLayer.path = bar.cgPath
    }

    // MARK: - Animation

    private func start() {
        // Pfade/Frames werden in layoutSubviews() gesetzt – Layout erzwingen, BEVOR
        // animiert wird, sonst ist markContainer.frame == .zero und path == nil und
        // es wird nichts gezeichnet (nur der Hintergrund erscheint).
        setNeedsLayout()
        layoutIfNeeded()

        // Startzustände als Modellwerte
        hexLayer.strokeEnd = 0
        barLayer.strokeEnd = 0
        markContainer.setValue(0.94, forKeyPath: "transform.scale")
        wordmark.alpha = 0
        wordmark.transform = CGAffineTransform(translationX: 0, y: 12)

        // Choreografie über echte Wanduhr-Delays. Jede Stufe startet sofort (kein
        // absoluter beginTime), wenn die Layer sicher im Render-Tree committet sind –
        // das behebt das Überspringen der Animationen beim Cold-Launch.
        runStaged(0.10) {
            self.drawStroke(self.hexLayer, duration: 0.62,
                            timing: CAMediaTimingFunction(controlPoints: 0.66, 0, 0.18, 1))
        }
        runStaged(0.50) {
            self.drawStroke(self.barLayer, duration: 0.38,
                            timing: CAMediaTimingFunction(controlPoints: 0.4, 0, 0.18, 1))
        }
        runStaged(0.62) {
            let pop = CASpringAnimation(keyPath: "transform.scale")
            pop.fromValue = 0.94
            pop.toValue = 1.0
            pop.damping = 12
            pop.stiffness = 220
            pop.duration = pop.settlingDuration
            self.markContainer.setValue(1.0, forKeyPath: "transform.scale")
            self.markContainer.add(pop, forKey: "pop")
        }

        // Wortmarke steigt auf (UIView-Animation mit Delay ist hier zuverlässig)
        UIView.animate(withDuration: 0.55, delay: 0.88,
                       usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
            self.wordmark.alpha = 1
            self.wordmark.transform = .identity
        }

        // Ausblenden, sobald die Choreografie durch ist (Flutter rendert darunter weiter)
        runStaged(1.9) {
            UIView.animate(withDuration: 0.35, animations: { self.alpha = 0 }) { _ in
                self.removeFromSuperview()
            }
        }
    }

    private func runStaged(_ delay: TimeInterval, _ block: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: block)
    }

    private func drawStroke(_ layer: CAShapeLayer, duration: CFTimeInterval,
                            timing: CAMediaTimingFunction) {
        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1
        draw.duration = duration
        draw.timingFunction = timing
        layer.strokeEnd = 1
        layer.add(draw, forKey: "draw")
    }

    // MARK: - Sora Variable Font (wght 600), Fallback: System Semibold

    private static var fontRegistered = false

    private static func soraFont(size: CGFloat) -> UIFont {
        if !fontRegistered,
           let url = Bundle.main.url(forResource: "Sora-Variable", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            fontRegistered = true
        }
        guard let base = UIFont(name: "Sora-Regular", size: size) else {
            return UIFont.systemFont(ofSize: size, weight: .semibold)
        }
        let variation = [2003265652: 600] // 'wght' Achsen-Tag
        let descriptor = base.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variation
        ])
        return UIFont(descriptor: descriptor, size: size)
    }
}
