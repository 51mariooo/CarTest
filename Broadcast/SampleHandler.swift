import CoreImage
import ImageIO
import Network
import ReplayKit
import UIKit

/// Screen-broadcast extension: iOS hands us every frame of the iPhone screen.
/// We shrink each frame, turn it into a JPEG and send it to the CarMirror app
/// over a local connection (127.0.0.1 only — nothing leaves the phone).
/// Audio isn't sent: while CarPlay is connected, iOS already plays all
/// iPhone sound through the car speakers.
class SampleHandler: RPBroadcastSampleHandler {
    private let sender = FrameSender(port: MirrorConfig.port)
    private let ciContext = CIContext()
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private var lastSent: CFTimeInterval = 0

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        sender.start()
    }

    override func broadcastFinished() {
        sender.stop()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video, sender.isReady else { return }

        let now = CACurrentMediaTime()
        guard now - lastSent >= 1.0 / MirrorConfig.maxFPS else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastSent = now

        // Rotate frames when the phone is sideways (e.g. full-screen video).
        var orientation = CGImagePropertyOrientation.up
        if let raw = CMGetAttachment(sampleBuffer,
                                     key: RPVideoSampleOrientationKey as CFString,
                                     attachmentModeOut: nil) as? NSNumber,
           let o = CGImagePropertyOrientation(rawValue: raw.uint32Value) {
            orientation = o
        }

        var image = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        let longest = max(image.extent.width, image.extent.height)
        let scale = min(1, MirrorConfig.maxSide / longest)
        if scale < 1 {
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        let qualityKey = CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)
        let options: [CIImageRepresentationOption: Any] = [qualityKey: MirrorConfig.jpegQuality]
        guard let jpeg = ciContext.jpegRepresentation(of: image, colorSpace: colorSpace, options: options) else { return }
        sender.send(jpeg)
    }
}

enum MirrorConfig {
    static let port: UInt16 = 52525
    static let maxFPS: Double = 30
    static let maxSide: CGFloat = 1280
    static let jpegQuality: CGFloat = 0.55
}

/// Sends length-prefixed JPEG frames to the app, reconnecting if needed.
final class FrameSender {
    private let port: NWEndpoint.Port
    private let queue = DispatchQueue(label: "carmirror.sender")
    private var connection: NWConnection?
    private var pending = 0
    private var running = false
    private(set) var isReady = false

    init(port: UInt16) {
        self.port = NWEndpoint.Port(rawValue: port)!
    }

    func start() {
        queue.async {
            self.running = true
            self.connect()
        }
    }

    func stop() {
        queue.async {
            self.running = false
            self.isReady = false
            self.connection?.cancel()
            self.connection = nil
        }
    }

    func send(_ jpeg: Data) {
        queue.async {
            // Drop frames if the app is falling behind, so video stays live.
            guard self.isReady, let connection = self.connection, self.pending < 2 else { return }
            var length = UInt32(jpeg.count).bigEndian
            var packet = Data(bytes: &length, count: 4)
            packet.append(jpeg)
            self.pending += 1
            connection.send(content: packet, completion: .contentProcessed { [weak self] _ in
                guard let self else { return }
                if self.pending > 0 { self.pending -= 1 }
            })
        }
    }

    private func connect() {
        guard running else { return }
        pending = 0
        let connection = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.isReady = true
            case .waiting, .failed:
                self.isReady = false
                connection?.cancel()
                self.retry()
            case .cancelled:
                self.isReady = false
            default:
                break
            }
        }
        self.connection = connection
        connection.start(queue: queue)
    }

    private func retry() {
        queue.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, self.running, !self.isReady else { return }
            self.connect()
        }
    }
}
