import UIKit

/// Animated night-sky background: slowly drifting, twinkling stars
/// plus shooting stars at random places and times. Uses CAEmitterLayer (GPU, very light).
final class StarfieldView: UIView {
    private let stars = CAEmitterLayer()
    private var meteorTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let dot = Self.dotImage(size: 8)

        // Faint background stars.
        let faint = CAEmitterCell()
        faint.contents = dot
        faint.birthRate = 6
        faint.lifetime = 14
        faint.scale = 0.18
        faint.scaleRange = 0.12
        faint.alphaRange = 0.5
        faint.alphaSpeed = -0.05
        faint.velocity = 4
        faint.velocityRange = 3
        faint.emissionRange = .pi * 2
        faint.color = UIColor(white: 1, alpha: 0.7).cgColor

        // Brighter twinkling stars with a blue tint.
        let bright = CAEmitterCell()
        bright.contents = dot
        bright.birthRate = 1.5
        bright.lifetime = 8
        bright.scale = 0.35
        bright.scaleRange = 0.15
        bright.scaleSpeed = -0.02
        bright.alphaRange = 0.4
        bright.alphaSpeed = -0.1
        bright.velocity = 6
        bright.velocityRange = 4
        bright.emissionRange = .pi * 2
        bright.color = UIColor(red: 0.75, green: 0.87, blue: 1, alpha: 1).cgColor
        bright.blueRange = 0.2

        stars.emitterShape = .rectangle
        stars.emitterMode = .surface
        stars.emitterCells = [faint, bright]
        // Pre-fill the sky so it isn't empty on launch.
        stars.beginTime = CACurrentMediaTime() - 14
        layer.addSublayer(stars)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        stars.frame = bounds
        stars.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        stars.emitterSize = bounds.size
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { scheduleMeteor() } else { meteorTimer?.invalidate() }
    }

    deinit { meteorTimer?.invalidate() }

    // MARK: Shooting stars — random place, direction, length, speed and timing.

    private func scheduleMeteor() {
        meteorTimer?.invalidate()
        meteorTimer = Timer.scheduledTimer(withTimeInterval: .random(in: 2.5...7), repeats: false) { [weak self] _ in
            guard let self, self.window != nil else { return }
            self.launchMeteor()
            self.scheduleMeteor()
        }
    }

    private func launchMeteor() {
        guard !isHidden, bounds.width > 0, bounds.height > 0 else { return }

        let start = CGPoint(x: .random(in: 0...bounds.width),
                            y: .random(in: 0...(bounds.height * 0.7)))
        let goesLeft = Bool.random()
        let angle = CGFloat.random(in: 0.2...0.45) * .pi          // 36°–81° below horizontal
        let distance = CGFloat.random(in: 120...280)
        let dx = cos(angle) * distance * (goesLeft ? -1 : 1)
        let dy = sin(angle) * distance
        let end = CGPoint(x: start.x + dx, y: start.y + dy)

        let streak = CAGradientLayer()
        streak.colors = [UIColor.white.withAlphaComponent(0).cgColor,
                         UIColor(red: 0.8, green: 0.9, blue: 1, alpha: 1).cgColor]
        streak.startPoint = CGPoint(x: 0, y: 0.5)
        streak.endPoint = CGPoint(x: 1, y: 0.5)
        streak.bounds = CGRect(x: 0, y: 0, width: .random(in: 50...110), height: .random(in: 1.2...2.2))
        streak.cornerRadius = 1
        streak.anchorPoint = CGPoint(x: 1, y: 0.5)              // bright head leads
        streak.position = end
        streak.opacity = 0
        streak.transform = CATransform3DMakeRotation(atan2(dy, dx), 0, 0, 1)
        layer.addSublayer(streak)

        let move = CABasicAnimation(keyPath: "position")
        move.fromValue = NSValue(cgPoint: start)
        move.toValue = NSValue(cgPoint: end)

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 1, 0]
        fade.keyTimes = [0, 0.15, 0.6, 1]

        let group = CAAnimationGroup()
        group.animations = [move, fade]
        group.duration = .random(in: 0.5...1.1)
        group.timingFunction = CAMediaTimingFunction(name: .easeIn)

        CATransaction.begin()
        CATransaction.setCompletionBlock { streak.removeFromSuperlayer() }
        streak.add(group, forKey: "meteor")
        CATransaction.commit()
    }

    private static func dotImage(size: CGFloat) -> CGImage? {
        UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
        }.cgImage
    }
}
