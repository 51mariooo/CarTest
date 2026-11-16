import CarPlay
import UIKit

/// Runs when the app is opened on the CarPlay screen.
/// Uses the navigation-app window, which lets us draw anything full-screen —
/// the same thing the mirroring app will need.
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    var carWindow: CPWindow?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        self.carWindow = window
        window.rootViewController = CarScreenViewController()
        interfaceController.setRootTemplate(CPMapTemplate(), animated: false, completion: nil)
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        self.interfaceController = nil
        self.carWindow = nil
    }
}

/// Green screen with a live counter, to prove we can draw moving content in the car.
final class CarScreenViewController: UIViewController {
    private let label = UILabel()
    private var timer: Timer?
    private var seconds = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGreen

        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
        ])
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.seconds += 1
            self?.update()
        }
    }

    private func update() {
        label.text = "CarPlay works ✅\nMirroring is possible\n\(seconds)s"
    }

    deinit { timer?.invalidate() }
}
