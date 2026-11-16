import Network
import UIKit

extension Notification.Name {
    static let mirrorStatusChanged = Notification.Name("mirrorStatusChanged")
    static let carPlayStatusChanged = Notification.Name("carPlayStatusChanged")
}

/// Listens on 127.0.0.1 for frames from the broadcast extension.
final class FrameReceiver {
    static let shared = FrameReceiver()
    static let port: UInt16 = 52525

    /// Called on the main thread with each decoded frame.
    var onFrame: ((UIImage) -> Void)?
    private(set) var isMirroring = false

    private let queue = DispatchQueue(label: "carmirror.receiver")
    private var listener: NWListener?
    private var connection: NWConnection?

    func start() {
        queue.async { self.startListener() }
    }

    private func startListener() {
        guard listener == nil else { return }
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback
        params.allowLocalEndpointReuse = true
        guard let port = NWEndpoint.Port(rawValue: Self.port),
              let listener = try? NWListener(using: params, on: port) else {
            queue.asyncAfter(deadline: .now() + 2) { self.startListener() }
            return
        }
        listener.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .failed = state {
                self.listener?.cancel()
                self.listener = nil
                self.queue.asyncAfter(deadline: .now() + 2) { self.startListener() }
            }
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    private func accept(_ conn: NWConnection) {
        connection?.cancel()
        connection = conn
        conn.stateUpdateHandler = { [weak self, weak conn] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.setMirroring(true)
            case .failed, .cancelled:
                if self.connection === conn { self.setMirroring(false) }
            default:
                break
            }
        }
        conn.start(queue: queue)
        readHeader(conn)
    }

    private func readHeader(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, _, error in
            guard let self, let data, data.count == 4, error == nil else {
                conn.cancel()
                return
            }
            let length = data.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard length > 0, length < 20_000_000 else {
                conn.cancel()
                return
            }
            self.readBody(conn, length: Int(length))
        }
    }

    private func readBody(_ conn: NWConnection, length: Int) {
        conn.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] data, _, _, error in
            guard let self, let data, data.count == length, error == nil else {
                conn.cancel()
                return
            }
            if let image = UIImage(data: data)?.preparingForDisplay() {
                DispatchQueue.main.async { self.onFrame?(image) }
            }
            self.readHeader(conn)
        }
    }

    private func setMirroring(_ value: Bool) {
        DispatchQueue.main.async {
            self.isMirroring = value
            NotificationCenter.default.post(name: .mirrorStatusChanged, object: nil)
        }
    }
}
