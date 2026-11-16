import CarPlay
import UIKit

/// The car screen. Uses the navigation-app window so we can draw
/// the mirrored iPhone screen full-size.
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    static private(set) var isConnected = false

    var interfaceController: CPInterfaceController?
    var carWindow: CPWindow?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        self.carWindow = window
        FrameReceiver.shared.start()
        window.rootViewController = CarScreenViewController()
        interfaceController.setRootTemplate(CPMapTemplate(), animated: false, completion: nil)
        Self.isConnected = true
        NotificationCenter.default.post(name: .carPlayStatusChanged, object: nil)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        self.interfaceController = nil
        self.carWindow = nil
        Self.isConnected = false
        NotificationCenter.default.post(name: .carPlayStatusChanged, object: nil)
    }
}

final class CarScreenViewController: UIViewController {
    private let imageView = UIImageView()
    private let waitingView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        imageView.contentMode = .scaleAspectFit
        imageView.frame = view.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(imageView)

        // "Ready" screen shown until mirroring starts.
        let icon = UIImageView(image: UIImage(systemName: "iphone.and.arrow.forward",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)))
        icon.tintColor = UIColor(red: 0.20, green: 0.58, blue: 1.00, alpha: 1)
        let title = UILabel()
        title.text = "Ready to mirror"
        title.font = .systemFont(ofSize: 26, weight: .heavy)
        title.textColor = .white
        let subtitle = UILabel()
        subtitle.text = "Tap Start in CarMirror on your iPhone"
        subtitle.font = .systemFont(ofSize: 16, weight: .medium)
        subtitle.textColor = UIColor(white: 0.6, alpha: 1)
        for v in [icon, title, subtitle] { waitingView.addArrangedSubview(v) }
        waitingView.axis = .vertical
        waitingView.alignment = .center
        waitingView.spacing = 10
        waitingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(waitingView)
        NSLayoutConstraint.activate([
            waitingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            waitingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        FrameReceiver.shared.onFrame = { [weak self] image in
            self?.imageView.image = image
            self?.waitingView.isHidden = true
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(statusChanged),
            name: .mirrorStatusChanged, object: nil)
    }

    @objc private func statusChanged() {
        if !FrameReceiver.shared.isMirroring {
            imageView.image = nil
            waitingView.isHidden = false
        }
    }
}
