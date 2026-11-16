import UIKit

/// Animated night-sky background: slowly drifting, twinkling stars
/// plus an occasional shooting star. Uses CAEmitterLayer (GPU, very light).
final class StarfieldView: UIView {
    private let stars = CAEmitterLayer()
    private let shooting = CAEmitterLayer()

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
        let streak = Self.streakImage()

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

        // Occasional shooting star, top-right to bottom-left.
        let meteor = CAEmitterCell()
        meteor.contents = streak
        meteor.birthRate = 0.12
        meteor.lifetime = 1.6
        meteor.velocity = 520
        meteor.velocityRange = 120
        meteor.emissionLongitude = .pi * 0.75
        meteor.emissionRange = .pi * 0.04
        meteor.rotation = .pi * 0.75
        meteor.scale = 0.6
        meteor.alphaSpeed = -0.7
        shooting.emitterShape = .line
        shooting.emitterCells = [meteor]
        layer.addSublayer(shooting)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        stars.frame = bounds
        stars.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        stars.emitterSize = bounds.size
        shooting.frame = bounds
        shooting.emitterPosition = CGPoint(x: bounds.width * 0.75, y: -10)
        shooting.emitterSize = CGSize(width: bounds.width, height: 1)
    }

    private static func dotImage(size: CGFloat) -> CGImage? {
        UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
        }.cgImage
    }

    private static func streakImage() -> CGImage? {
        let size = CGSize(width: 90, height: 3)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: 0), options: [])
            }
        }.cgImage
    }
}
