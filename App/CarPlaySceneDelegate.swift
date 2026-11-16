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
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        imageView.contentMode = .scaleAspectFit
        imageView.frame = view.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(imageView)

        // Green "test passed" screen shown until mirroring starts.
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.textColor = .white
        statusLabel.backgroundColor = .systemGreen
        statusLabel.font = .systemFont(ofSize: 26, weight: .bold)
        statusLabel.text = "CarPlay works ✅\nOpen CarMirror on your iPhone\nand tap Start Mirroring"
        statusLabel.frame = view.bounds
        statusLabel.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(statusLabel)

        FrameReceiver.shared.onFrame = { [weak self] image in
            self?.imageView.image = image
            self?.statusLabel.isHidden = true
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(statusChanged),
            name: .mirrorStatusChanged, object: nil)
    }

    @objc private func statusChanged() {
        if !FrameReceiver.shared.isMirroring {
            imageView.image = nil
            statusLabel.isHidden = false
        }
    }
}
