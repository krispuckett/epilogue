import SwiftUI
import AVFoundation

// MARK: - Live Camera View
/// High-performance camera feed for real-time text recognition
/// Processes frames and sends to Vision for OCR

struct LiveCameraView: UIViewControllerRepresentable {
    let onFrame: (CVPixelBuffer) async -> Void

    func makeUIViewController(context: Context) -> LiveCameraViewController {
        LiveCameraViewController(onFrame: onFrame)
    }

    func updateUIViewController(_ uiViewController: LiveCameraViewController, context: Context) {}
}

// MARK: - Live Camera View Controller

class LiveCameraViewController: UIViewController {
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let videoOutput = AVCaptureVideoDataOutput()
    private let onFrame: (CVPixelBuffer) async -> Void

    private var frameCount = 0

    init(onFrame: @escaping (CVPixelBuffer) async -> Void) {
        self.onFrame = onFrame
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080  // Good balance for text recognition

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            #if DEBUG
            print("❌ [LIVE CAMERA] Failed to get camera device")
            #endif
            return
        }

        // Configure camera for book scanning
        do {
            try camera.lockForConfiguration()

            // Continuous autofocus for steady text
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }

            // Auto exposure
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }

            camera.unlockForConfiguration()

            #if DEBUG
            print("✅ [LIVE CAMERA] Camera configured: autofocus + autoexposure")
            #endif
        } catch {
            #if DEBUG
            print("❌ [LIVE CAMERA] Configuration error: \(error)")
            #endif
        }

        // Add camera input
        guard let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            #if DEBUG
            print("❌ [LIVE CAMERA] Failed to create camera input")
            #endif
            return
        }
        session.addInput(input)

        // Configure video output for Vision processing
        videoOutput.setSampleBufferDelegate(
            self,
            queue: DispatchQueue(label: "com.epilogue.livecamera.processing", qos: .userInitiated)
        )
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)

            // Enable video stabilization
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .standard
                }
            }

            #if DEBUG
            print("✅ [LIVE CAMERA] Video output configured")
            #endif
        }

        session.commitConfiguration()

        // Setup preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        // Start session on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            #if DEBUG
            DispatchQueue.main.async {
                print("🎬 [LIVE CAMERA] Starting session...")
            }
            #endif

            self?.session.startRunning()

            #if DEBUG
            DispatchQueue.main.async {
                print("🎬 [LIVE CAMERA] ✅ Session started successfully")
                print("🎬 [LIVE CAMERA] Preview layer frame: \(String(describing: self?.previewLayer.frame))")
            }
            #endif
        }
    }

    deinit {
        #if DEBUG
        print("♻️ [LIVE CAMERA] Stopping session")
        #endif

        if session.isRunning {
            session.stopRunning()
        }
    }
}

// MARK: - Sample Buffer Delegate

extension LiveCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Extract pixel buffer IMMEDIATELY (synchronously) before buffer gets recycled
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            #if DEBUG
            print("⚠️ [LIVE CAMERA] No pixel buffer in sample")
            #endif
            return
        }

        #if DEBUG
        frameCount += 1
        if frameCount % 30 == 0 {  // Log every 30 frames
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            print("📹 [LIVE CAMERA] Captured frame: \(width)x\(height)")
        }
        #endif

        // Process frame - pixel buffer is automatically retained by async context
        Task {
            await onFrame(pixelBuffer)
        }
    }
}
