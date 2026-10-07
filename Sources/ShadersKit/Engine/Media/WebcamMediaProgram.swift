#if canImport(Metal)
import Foundation
import Metal

#if os(iOS) || os(macOS)
import AVFoundation

/// `WebcamTexture`: streams the front camera (any camera as fallback) at up to 1280×720 into
/// `video_0` via `AVCaptureVideoDataOutput` → `CVMetalTextureCache` (linear bgra8Unorm).
/// The shader applies the selfie mirror (`mirror` prop). Frames are upright for the current
/// device orientation. Capture asks for camera permission on first use, needs
/// `NSCameraUsageDescription` in the app's Info.plist (without it nothing starts), and stops while
/// the node is not rendering. The result is empty until the first frame arrives.
final class WebcamMediaProgram: MediaProgram {
    static let shaderNames = ["WebcamTexture"]

    private let textures: PixelBufferTextureCache
    private let receiver = FrameReceiver()
    private let session = AVCaptureSession()
    /// Serializes session configuration, start and stop (`startRunning` blocks).
    private let sessionQueue = DispatchQueue(label: "ShadersKit.WebcamMediaProgram.session")
    private let captureQueue = DispatchQueue(label: "ShadersKit.WebcamMediaProgram.frames")
    private var watchdog: IdleWatchdog?
    private var rotation: RotationTracker?

    // Render-thread state.
    private var current: CVMetalTexture?
    private var currentSequence = 0

    init(context: MediaContext) throws {
        guard let cache = PixelBufferTextureCache(device: context.device.device) else { throw ShaderEngineError.noMetalDevice }
        textures = cache
        // Requesting camera access without a usage description terminates the app.
        guard Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil else { return }
        let session = session
        watchdog = IdleWatchdog(queue: sessionQueue) { session.stopRunning() }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sessionQueue.async { [weak self] in self?.configureAndStart() }
        case .notDetermined:
            let queue = sessionQueue
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                queue.async { self?.configureAndStart() }
            }
        default:
            break
        }
    }

    deinit {
        let session = session
        sessionQueue.async { session.stopRunning() }
    }

    func encode(_ ctx: MediaContext) throws -> MediaOutputs {
        if watchdog?.touch() == true {
            sessionQueue.async { [session] in
                if !session.inputs.isEmpty, !session.isRunning { session.startRunning() }
            }
        }
        if let (buffer, sequence) = receiver.latest(), sequence != currentSequence {
            currentSequence = sequence
            if let tex = textures.texture(from: buffer) { current = tex }
        }
        guard let current, let mtl = CVMetalTextureGetTexture(current) else { return MediaOutputs() }
        ctx.commandBuffer.keepAlive(current)
        return MediaOutputs(textures: ["video_0": mtl])
    }

    /// Runs on `sessionQueue`.
    private func configureAndStart() {
        guard session.inputs.isEmpty else { return }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }
        session.beginConfiguration()
        if session.canSetSessionPreset(.hd1280x720) { session.sessionPreset = .hd1280x720 }
        guard session.canAddInput(input) else { session.commitConfiguration(); return }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(receiver, queue: captureQueue)
        guard session.canAddOutput(output) else { session.commitConfiguration(); return }
        session.addOutput(output)
        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            // The shader mirrors (`mirror` prop); deliver the camera's natural orientation.
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        session.commitConfiguration()
        if let connection = output.connection(with: .video) {
            rotation = RotationTracker(device: camera, connection: connection, queue: sessionQueue)
        }
        session.startRunning()
    }
}

/// Keeps the latest camera frame (written on the capture queue, read on the render thread).
private final class FrameReceiver: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let lock = NSLock()
    private var buffer: CVPixelBuffer?
    private var sequence = 0

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lock.lock()
        buffer = pb
        sequence += 1
        lock.unlock()
    }

    func latest() -> (CVPixelBuffer, Int)? {
        lock.lock(); defer { lock.unlock() }
        return buffer.map { ($0, sequence) }
    }
}

/// Rotates the capture connection so frames stay upright as the device turns.
private final class RotationTracker {
    private let coordinator: AVCaptureDevice.RotationCoordinator
    private var observation: NSKeyValueObservation?

    init(device: AVCaptureDevice, connection: AVCaptureConnection, queue: DispatchQueue) {
        coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        let apply: (CGFloat) -> Void = { angle in
            if connection.isVideoRotationAngleSupported(angle) { connection.videoRotationAngle = angle }
        }
        apply(coordinator.videoRotationAngleForHorizonLevelCapture)
        observation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            queue.async { apply(angle) }
        }
    }
}

#else

/// `WebcamTexture` on platforms without camera capture (tvOS, visionOS): renders nothing.
final class WebcamMediaProgram: MediaProgram {
    static let shaderNames = ["WebcamTexture"]
    init(context: MediaContext) throws {}
    func encode(_ ctx: MediaContext) throws -> MediaOutputs { MediaOutputs() }
}

#endif
#endif
