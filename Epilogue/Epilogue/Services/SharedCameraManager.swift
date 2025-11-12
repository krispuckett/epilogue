import AVFoundation
import UIKit
import OSLog
import Combine

// Make logger and debug flag nonisolated and sendable
nonisolated(unsafe) private let logger = Logger(subsystem: "com.epilogue", category: "SharedCameraManager")
nonisolated(unsafe) private let CAMERA_DEBUG = true

// MARK: - Shared Camera Manager
// Reusable AVFoundation camera for smooth capture experience
// Used by: AmbientTextCapture (experimental), potentially BookScanner in future

@MainActor
class SharedCameraManager: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var captureError: CaptureError?

    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var photoCaptureDelegate: ExperimentalPhotoCaptureDelegate?

    enum CaptureError: LocalizedError {
        case cameraUnavailable
        case permissionDenied
        case captureFailed
        case sessionNotRunning

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable: return "Camera is not available"
            case .permissionDenied: return "Camera permission denied"
            case .captureFailed: return "Failed to capture photo"
            case .sessionNotRunning: return "Camera session is not running"
            }
        }
    }

    override init() {
        super.init()

        #if DEBUG
        if CAMERA_DEBUG {
            logger.info("🎥 [EXPERIMENT] SharedCameraManager initializing")
        }
        #endif

        setupCamera()
    }

    private func setupCamera() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        #if DEBUG
        if CAMERA_DEBUG {
            logger.info("🎥 [EXPERIMENT] Configuring camera session")
        }
        #endif

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            #if DEBUG
            logger.error("❌ [EXPERIMENT] Failed to get camera device")
            #endif
            captureError = .cameraUnavailable
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: camera) else {
            #if DEBUG
            logger.error("❌ [EXPERIMENT] Failed to create camera input")
            #endif
            captureError = .cameraUnavailable
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
            #if DEBUG
            if CAMERA_DEBUG {
                logger.info("✅ [EXPERIMENT] Camera input added")
            }
            #endif
        }

        // Configure camera for optimal quality
        do {
            try camera.lockForConfiguration()
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }
            camera.unlockForConfiguration()

            #if DEBUG
            if CAMERA_DEBUG {
                logger.info("✅ [EXPERIMENT] Camera configured: autofocus + autoexposure")
            }
            #endif
        } catch {
            #if DEBUG
            logger.error("❌ [EXPERIMENT] Failed to configure camera: \(error.localizedDescription)")
            #endif
        }

        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            #if DEBUG
            if CAMERA_DEBUG {
                logger.info("✅ [EXPERIMENT] Photo output added")
            }
            #endif
        }
    }

    func startSession() {
        guard !session.isRunning else {
            #if DEBUG
            if CAMERA_DEBUG {
                logger.info("⏭️ [EXPERIMENT] Session already running")
            }
            #endif
            return
        }

        #if DEBUG
        if CAMERA_DEBUG {
            logger.info("🎬 [EXPERIMENT] Starting camera session")
        }
        #endif

        Task.detached(priority: .userInitiated) { [weak self] in
            let startTime = Date()
            self?.session.startRunning()

            await MainActor.run {
                self?.isSessionRunning = true

                #if DEBUG
                if CAMERA_DEBUG {
                    let elapsed = Date().timeIntervalSince(startTime)
                    logger.info("✅ [EXPERIMENT] Camera session started (\(String(format: "%.2f", elapsed))s)")
                }
                #endif
            }
        }
    }

    func stopSession() {
        guard session.isRunning else { return }

        #if DEBUG
        if CAMERA_DEBUG {
            logger.info("🛑 [EXPERIMENT] Stopping camera session")
        }
        #endif

        session.stopRunning()
        isSessionRunning = false
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        #if DEBUG
        if CAMERA_DEBUG {
            logger.info("📸 [EXPERIMENT] capturePhoto called")
            logger.info("   Session running: \(self.session.isRunning)")
        }
        #endif

        // Simulator fallback
        #if targetEnvironment(simulator)
        #if DEBUG
        logger.warning("⚠️ [EXPERIMENT] Running on simulator - returning nil")
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            completion(nil)
        }
        return
        #endif

        // Validate session is running
        guard session.isRunning else {
            #if DEBUG
            logger.error("❌ [EXPERIMENT] Session not running, cannot capture")
            #endif
            captureError = .sessionNotRunning
            completion(nil)
            return
        }

        // Validate photo output is ready
        guard !photoOutput.connections.isEmpty else {
            #if DEBUG
            logger.error("❌ [EXPERIMENT] No connections on photo output")
            #endif
            captureError = .captureFailed
            completion(nil)
            return
        }

        guard let connection = photoOutput.connection(with: .video), connection.isActive else {
            #if DEBUG
            logger.error("❌ [EXPERIMENT] Video connection not active or not found")
            #endif
            captureError = .captureFailed
            completion(nil)
            return
        }

        // Verify the session's inputs and outputs are properly connected
        guard !session.inputs.isEmpty && !session.outputs.isEmpty else {
            #if DEBUG
            logger.error("❌ [EXPERIMENT] Session has no inputs or outputs")
            #endif
            captureError = .captureFailed
            completion(nil)
            return
        }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off

        // Only set quality if supported - this was causing the crash
        if photoOutput.maxPhotoQualityPrioritization.rawValue >= AVCapturePhotoOutput.QualityPrioritization.balanced.rawValue {
            settings.photoQualityPrioritization = .balanced
        }

        #if DEBUG
        let captureStartTime = Date()
        if CAMERA_DEBUG {
            logger.info("📸 [EXPERIMENT] Initiating photo capture...")
            logger.info("   Photo output ready: \(self.photoOutput.isStillImageStabilizationSupported)")
        }
        #endif

        // Store delegate to prevent deallocation
        let delegate = ExperimentalPhotoCaptureDelegate { [weak self] image in
            #if DEBUG
            if CAMERA_DEBUG {
                let elapsed = Date().timeIntervalSince(captureStartTime)
                logger.info("📸 [EXPERIMENT] Photo delegate callback (\(String(format: "%.2f", elapsed))s)")
                if let image = image {
                    logger.info("   Image: ✅ \(image.size.width)x\(image.size.height)")
                } else {
                    logger.info("   Image: ❌ nil")
                }
            }
            #endif

            DispatchQueue.main.async {
                if image == nil {
                    self?.captureError = .captureFailed
                }
                completion(image)
                self?.photoCaptureDelegate = nil

                #if DEBUG
                if CAMERA_DEBUG {
                    logger.info("🧹 [EXPERIMENT] Photo delegate cleaned up")
                }
                #endif
            }
        }

        photoCaptureDelegate = delegate

        // All validation passed - safe to capture
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    deinit {
        #if DEBUG
        if CAMERA_DEBUG {
            logger.info("♻️ [EXPERIMENT] SharedCameraManager deinit")
        }
        #endif
        // Note: Session cleanup happens automatically on deallocation
    }
}

// MARK: - Experimental Photo Capture Delegate

class ExperimentalPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        #if DEBUG
        if CAMERA_DEBUG {
            logger.info("📸 [EXPERIMENT] PhotoCaptureDelegate - didFinishProcessingPhoto")
        }
        #endif

        if let error = error {
            #if DEBUG
            logger.error("❌ [EXPERIMENT] Photo capture error: \(error.localizedDescription)")
            #endif
            completion(nil)
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            #if DEBUG
            logger.error("❌ [EXPERIMENT] No photo data representation")
            #endif
            completion(nil)
            return
        }

        guard let image = UIImage(data: data) else {
            #if DEBUG
            logger.error("❌ [EXPERIMENT] Failed to create UIImage from data")
            #endif
            completion(nil)
            return
        }

        #if DEBUG
        if CAMERA_DEBUG {
            logger.info("✅ [EXPERIMENT] Photo captured successfully: \(image.size.width)x\(image.size.height)")
        }
        #endif

        completion(image)
    }
}
