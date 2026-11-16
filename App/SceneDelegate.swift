import ReplayKit
import UIKit

/// The iPhone screen: status + Start/Stop Mirroring button.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = PhoneViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}

enum Theme {
    static let accent = UIColor(red: 0.20, green: 0.58, blue: 1.00, alpha: 1)
    static let live = UIColor(red: 1.00, green: 0.27, blue: 0.33, alpha: 1)
    static let card = UIColor(white: 0.11, alpha: 1)
}

final class PhoneViewController: UIViewController {
    private let carStatus = UILabel()
    private let mirrorStatus = UILabel()
    private let carDot = UIView()
    private let mirrorDot = UIView()
    private let startButton = UIButton(type: .custom)
    private let buttonLabel = UILabel()
    private let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .black

        let sky = StarfieldView(frame: view.bounds)
        sky.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(sky)

        // Header
        let icon = UIImageView(image: UIImage(systemName: "car.side.fill"))
        icon.tintColor = Theme.accent
        icon.contentMode = .scaleAspectFit
        let title = UILabel()
        title.text = "CarMirror"
        title.font = .systemFont(ofSize: 32, weight: .heavy)
        title.textColor = .white
        let header = UIStackView(arrangedSubviews: [icon, title])
        header.spacing = 10
        header.alignment = .center

        // Status card
        let card = UIStackView(arrangedSubviews: [
            row(dot: carDot, label: carStatus),
            row(dot: mirrorDot, label: mirrorStatus),
        ])
        card.axis = .vertical
        card.spacing = 14
        card.isLayoutMarginsRelativeArrangement = true
        card.layoutMargins = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        card.backgroundColor = Theme.card.withAlphaComponent(0.85)
        card.layer.cornerRadius = 18

        // Big round start button
        startButton.layer.cornerRadius = 80
        startButton.layer.shadowOpacity = 0.6
        startButton.layer.shadowRadius = 24
        startButton.layer.shadowOffset = .zero
        startButton.addTarget(self, action: #selector(tapStart), for: .touchUpInside)
        let symbol = UIImageView(image: UIImage(systemName: "rectangle.on.rectangle",
                                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 38, weight: .semibold)))
        symbol.tintColor = .white
        symbol.isUserInteractionEnabled = false
        buttonLabel.font = .systemFont(ofSize: 17, weight: .bold)
        buttonLabel.textColor = .white
        let inner = UIStackView(arrangedSubviews: [symbol, buttonLabel])
        inner.axis = .vertical
        inner.alignment = .center
        inner.spacing = 8
        inner.isUserInteractionEnabled = false
        inner.translatesAutoresizingMaskIntoConstraints = false
        startButton.addSubview(inner)

        let help = UILabel()
        help.numberOfLines = 0
        help.textColor = UIColor(white: 0.55, alpha: 1)
        help.font = .systemFont(ofSize: 14)
        help.textAlignment = .center
        help.text = "Open CarMirror on the car screen, tap the button, choose CarMirror and Start Broadcast. Then open any app."

        picker.showsMicrophoneButton = false
        picker.preferredExtension = Self.broadcastExtensionID()
        picker.alpha = 0.01

        for v in [header, card, startButton, help, picker] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 34),
            header.topAnchor.constraint(equalTo: g.topAnchor, constant: 24),
            header.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 24),
            card.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 24),
            card.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -20),
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 60),
            startButton.widthAnchor.constraint(equalToConstant: 160),
            startButton.heightAnchor.constraint(equalToConstant: 160),
            inner.centerXAnchor.constraint(equalTo: startButton.centerXAnchor),
            inner.centerYAnchor.constraint(equalTo: startButton.centerYAnchor),
            help.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 32),
            help.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -32),
            help.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -24),
            picker.widthAnchor.constraint(equalToConstant: 1),
            picker.heightAnchor.constraint(equalToConstant: 1),
            picker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            picker.bottomAnchor.constraint(equalTo: help.topAnchor),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .mirrorStatusChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .carPlayStatusChanged, object: nil)
        refresh()
    }

    private func row(dot: UIView, label: UILabel) -> UIStackView {
        dot.layer.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 10).isActive = true
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        let r = UIStackView(arrangedSubviews: [dot, label])
        r.spacing = 12
        r.alignment = .center
        return r
    }

    @objc private func refresh() {
        let car = CarPlaySceneDelegate.isConnected
        let live = FrameReceiver.shared.isMirroring
        carStatus.text = car ? "Car screen connected" : "Open CarMirror in CarPlay"
        carDot.backgroundColor = car ? Theme.accent : UIColor(white: 0.35, alpha: 1)
        mirrorStatus.text = live ? "Mirroring live" : "Mirroring off"
        mirrorDot.backgroundColor = live ? Theme.live : UIColor(white: 0.35, alpha: 1)
        let color = live ? Theme.live : Theme.accent
        startButton.backgroundColor = color
        startButton.layer.shadowColor = color.cgColor
        buttonLabel.text = live ? "Stop" : "Start"
    }

    /// Opens the iOS broadcast sheet by tapping the system picker's button.
    @objc private func tapStart() {
        for case let button as UIButton in picker.subviews {
            button.sendActions(for: .allTouchEvents)
            return
        }
    }

    /// Finds the embedded broadcast extension's bundle ID at runtime,
    /// so it still works if the signing tool changes bundle IDs.
    private static func broadcastExtensionID() -> String? {
        guard let plugins = Bundle.main.builtInPlugInsURL,
              let items = try? FileManager.default.contentsOfDirectory(at: plugins, includingPropertiesForKeys: nil)
        else { return nil }
        for url in items where url.pathExtension == "appex" {
            if let id = Bundle(url: url)?.bundleIdentifier { return id }
        }
        return nil
    }
}
