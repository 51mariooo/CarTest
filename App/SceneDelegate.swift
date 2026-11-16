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

final class PhoneViewController: UIViewController {
    private let titleLabel = UILabel()
    private let carStatus = UILabel()
    private let mirrorStatus = UILabel()
    private let startButton = UIButton(type: .system)
    private let helpLabel = UILabel()
    private let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        titleLabel.text = "CarMirror"
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)

        for label in [carStatus, mirrorStatus] {
            label.font = .systemFont(ofSize: 18, weight: .medium)
        }

        var config = UIButton.Configuration.filled()
        config.cornerStyle = .large
        config.baseBackgroundColor = .systemGreen
        config.title = "Start / Stop Mirroring"
        config.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 24, bottom: 18, trailing: 24)
        startButton.configuration = config
        startButton.addTarget(self, action: #selector(tapStart), for: .touchUpInside)

        helpLabel.numberOfLines = 0
        helpLabel.textColor = .secondaryLabel
        helpLabel.font = .systemFont(ofSize: 15)
        helpLabel.text = """
        1. Connect to CarPlay and open CarMirror on the car screen.
        2. Tap Start / Stop Mirroring, pick "CarMirror", then Start Broadcast.
        3. Switch to any app — it shows on the car screen. Sound plays through the car as normal.
        To stop: tap the red bar/clock at the top of the iPhone, or this button again.
        """

        picker.showsMicrophoneButton = false
        picker.preferredExtension = Self.broadcastExtensionID()

        let stack = UIStackView(arrangedSubviews: [titleLabel, carStatus, mirrorStatus, startButton, picker, helpLabel])
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            startButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            picker.widthAnchor.constraint(equalToConstant: 60),
            picker.heightAnchor.constraint(equalToConstant: 60),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .mirrorStatusChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .carPlayStatusChanged, object: nil)
        refresh()
    }

    @objc private func refresh() {
        carStatus.text = CarPlaySceneDelegate.isConnected
            ? "🚗 Car screen: connected"
            : "🚗 Car screen: not connected (open CarMirror in CarPlay)"
        mirrorStatus.text = FrameReceiver.shared.isMirroring
            ? "🔴 Mirroring: ON"
            : "⚪️ Mirroring: off"
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
