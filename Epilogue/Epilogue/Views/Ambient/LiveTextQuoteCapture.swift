import SwiftUI
import VisionKit
import AVFoundation
import Vision
import Combine

// MARK: - Live Text Quote Capture
/// Live camera with automatic text detection - no shutter needed!
/// User points at text, taps to select, then refines selection naturally

@available(iOS 16.0, *)
struct LiveTextQuoteCapture: View {
    let bookContext: Book?
    let onQuoteSaved: (String, Int?) -> Void
    let onQuestionAsked: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LiveTextCaptureViewModel()
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var hasDetectedText = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let capturedImage = viewModel.capturedImage {
                // Show captured image with text selection
                LiveTextImageView(
                    image: capturedImage,
                    selectedText: $viewModel.selectedText,
                    onSelectionChange: { text in
                        viewModel.selectedText = text
                    }
                )
                .ignoresSafeArea()

                // Top bar with close
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .glassEffect(in: .circle)
                        }

                        Spacer()

                        // Hint when no selection
                        if viewModel.selectedText.isEmpty {
                            Text("Select text")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: .capsule)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)

                    Spacer()
                }

                // Bottom action bar - centered group of 3 buttons
                VStack {
                    Spacer()

                    if !viewModel.selectedText.isEmpty {
                        // All three buttons centered together
                        HStack(spacing: 12) {
                            // Retake
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    viewModel.capturedImage = nil
                                    viewModel.selectedText = ""
                                }
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .glassEffect(in: .circle)
                            }

                            // Save
                            Button {
                                saveQuote()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "bookmark.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Save")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .glassEffect(.regular.tint(Color.white.opacity(0.1)), in: .capsule)
                            }

                            // Ask
                            Button {
                                askQuestion()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "text.bubble.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Ask")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .glassEffect(.regular.tint(Color.orange.opacity(0.15)), in: .capsule)
                            }
                        }
                        .padding(.bottom, 34)
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.selectedText.isEmpty)
                    } else {
                        // Just retake when no text selected
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                viewModel.capturedImage = nil
                                viewModel.selectedText = ""
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .glassEffect(in: .circle)
                        }
                        .padding(.bottom, 34)
                    }
                }

            } else {
                // Live camera with intelligent auto-capture
                SmartCaptureCamera(
                    onAutoCapture: { image in
                        // System detected good text and auto-captured
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.capturedImage = image
                        }
                    },
                    onStatusChange: { status in
                        hasDetectedText = (status == .ready)
                    }
                )
                .ignoresSafeArea()

                // Clean UI - system handles capture automatically
                VStack {
                    // Top bar
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .glassEffect(in: .circle)
                        }

                        Spacer()

                        // Status indicator
                        HStack(spacing: 6) {
                            if hasDetectedText {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                            }
                            Text(hasDetectedText ? "Capturing..." : "Point at text")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(hasDetectedText ? .white : .white.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.tint(hasDetectedText ? Color.orange.opacity(0.15) : Color.white.opacity(0.05)), in: .capsule)
                        .animation(.easeInOut(duration: 0.3), value: hasDetectedText)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)

                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .modifier(GlassToastModifier(isShowing: $showingToast, message: toastMessage))
    }

    private func saveQuote() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onQuoteSaved(viewModel.selectedText, nil)

        // Show toast
        toastMessage = "Quote saved"
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showingToast = true
        }

        // Dismiss after toast shows
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }

    private func askQuestion() {
        let question = "What does this mean: \"\(viewModel.selectedText)\""

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onQuestionAsked(question)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
        }
    }
}

// MARK: - View Model

@MainActor
class LiveTextCaptureViewModel: ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var selectedText: String = ""
    @Published var shouldCapture = false

    func requestCapture() {
        shouldCapture = true
    }
}

// MARK: - Live Camera Preview

struct LiveCameraPreview: UIViewControllerRepresentable {
    @Binding var shouldCapture: Bool
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onCapture = onCapture
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        if shouldCapture {
            uiViewController.capturePhoto()
        }
    }
}

class CameraViewController: UIViewController {
    var onCapture: ((UIImage) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let photoOutput = AVCapturePhotoOutput()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        // Use .high instead of .photo - still good for text, much more efficient
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else { return }

        do {
            // Limit frame rate for preview to save battery
            try camera.lockForConfiguration()
            camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30) // Cap at 30fps
            camera.unlockForConfiguration()

            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
            previewLayer = layer

            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        } catch {
            print("❌ Camera setup error: \(error)")
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    deinit {
        session.stopRunning()
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }

        DispatchQueue.main.async {
            self.onCapture?(image)
        }
    }
}

// MARK: - Smart Capture Camera (Auto-detects and captures)

enum CaptureStatus {
    case searching
    case ready
    case captured
}

struct SmartCaptureCamera: UIViewControllerRepresentable {
    let onAutoCapture: (UIImage) -> Void
    let onStatusChange: (CaptureStatus) -> Void

    func makeUIViewController(context: Context) -> SmartCaptureViewController {
        let controller = SmartCaptureViewController()
        controller.onAutoCapture = onAutoCapture
        controller.onStatusChange = onStatusChange
        return controller
    }

    func updateUIViewController(_ uiViewController: SmartCaptureViewController, context: Context) {}
}

class SmartCaptureViewController: UIViewController {
    var onAutoCapture: ((UIImage) -> Void)?
    var onStatusChange: ((CaptureStatus) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()

    private var textDetectionRequest: VNRecognizeTextRequest?
    private var frameCount = 0
    private var consecutiveGoodFrames = 0
    private var hasCaptured = false
    private let captureQueue = DispatchQueue(label: "com.epilogue.smartcapture", qos: .userInitiated)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextDetection()
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupTextDetection() {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleTextDetection(request: request, error: error)
        }
        request.recognitionLevel = .fast // Fast for detection, we'll do accurate on capture
        request.usesLanguageCorrection = false // Speed optimization
        textDetectionRequest = request
    }

    private func setupCamera() {
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else { return }

        do {
            // Limit frame rate
            try camera.lockForConfiguration()
            camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            camera.unlockForConfiguration()

            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            // Photo output for final capture
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            // Video output for frame analysis
            videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
            previewLayer = layer

            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
                #if DEBUG
                DispatchQueue.main.async {
                    print("🎥 [SMART CAPTURE] Session started running: \(self.session.isRunning)")
                }
                #endif
            }
        } catch {
            print("❌ Smart camera setup error: \(error)")
        }
    }

    private func handleTextDetection(request: VNRequest, error: Error?) {
        guard !hasCaptured else { return }

        if let error = error {
            #if DEBUG
            print("❌ [SMART CAPTURE] Text detection error: \(error)")
            #endif
            return
        }

        guard let observations = request.results as? [VNRecognizedTextObservation],
              !observations.isEmpty else {
            // No text found
            consecutiveGoodFrames = 0
            DispatchQueue.main.async {
                self.onStatusChange?(.searching)
            }
            return
        }

        #if DEBUG
        print("📝 [SMART CAPTURE] Found \(observations.count) text observations")
        #endif

        // Simple check: if we found 8+ text blocks, that's clearly a page - capture it!
        // No need for strict confidence filtering with fast recognition
        let hasEnoughText = observations.count >= 8

        #if DEBUG
        print("✅ [SMART CAPTURE] Has enough text: \(hasEnoughText), consecutive: \(consecutiveGoodFrames)")
        #endif

        if hasEnoughText {
            // Good text detected
            consecutiveGoodFrames += 1

            if consecutiveGoodFrames >= 2 {
                // Stable good text for 2 frames - auto capture immediately!
                hasCaptured = true
                #if DEBUG
                print("📸 [SMART CAPTURE] Auto-capturing now!")
                #endif
                DispatchQueue.main.async {
                    self.onStatusChange?(.ready)
                    self.capturePhoto()
                }
            } else {
                DispatchQueue.main.async {
                    self.onStatusChange?(.ready)
                }
            }
        } else {
            consecutiveGoodFrames = 0
            DispatchQueue.main.async {
                self.onStatusChange?(.searching)
            }
        }
    }

    private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    deinit {
        session.stopRunning()
    }
}

extension SmartCaptureViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !hasCaptured else { return }

        // Only analyze every 5th frame (6fps analysis instead of 30fps)
        frameCount += 1

        #if DEBUG
        if frameCount == 1 {
            print("🎥 [SMART CAPTURE] First frame received!")
        }
        #endif

        guard frameCount % 5 == 0 else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            #if DEBUG
            print("❌ [SMART CAPTURE] Failed to get pixel buffer")
            #endif
            return
        }

        #if DEBUG
        if frameCount == 5 {
            print("🔍 [SMART CAPTURE] Analyzing frame \(frameCount)")
        }
        #endif

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        if let request = textDetectionRequest {
            try? handler.perform([request])
        }
    }
}

extension SmartCaptureViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }

        DispatchQueue.main.async {
            self.onStatusChange?(.captured)
            self.onAutoCapture?(image)
        }
    }
}

// MARK: - Live Text Image View (Natural Selection)

struct LiveTextImageView: UIViewRepresentable {
    let image: UIImage
    @Binding var selectedText: String
    let onSelectionChange: (String) -> Void

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black

        let imageView = UIImageView()
        imageView.image = image
        imageView.contentMode = .scaleAspectFit  // Fit entire image without cropping
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        // Add Live Text interaction
        let interaction = ImageAnalysisInteraction()
        interaction.preferredInteractionTypes = .textSelection
        imageView.addInteraction(interaction)

        context.coordinator.interaction = interaction
        context.coordinator.imageView = imageView
        context.coordinator.startAnalysis(for: image)
        context.coordinator.startMonitoring()

        #if DEBUG
        print("📸 [LIVE TEXT] Image view created, starting analysis...")
        #endif

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        let parent: LiveTextImageView
        var interaction: ImageAnalysisInteraction?
        var imageView: UIImageView?
        private var selectionTimer: Timer?
        private let analyzer = ImageAnalyzer()

        init(_ parent: LiveTextImageView) {
            self.parent = parent
        }

        func startAnalysis(for image: UIImage) {
            Task {
                guard let interaction = interaction else {
                    print("❌ [LIVE TEXT] No interaction")
                    return
                }

                #if DEBUG
                print("🔍 [LIVE TEXT] Starting image analysis...")
                #endif

                do {
                    let configuration = ImageAnalyzer.Configuration([.text])
                    let analysis = try await analyzer.analyze(image, configuration: configuration)

                    await MainActor.run {
                        interaction.analysis = analysis
                        interaction.preferredInteractionTypes = .textSelection

                        #if DEBUG
                        print("✅ [LIVE TEXT] Analysis complete, text selection enabled")
                        #endif
                    }
                } catch {
                    #if DEBUG
                    print("❌ [LIVE TEXT] Analysis error: \(error)")
                    #endif
                }
            }
        }

        func startMonitoring() {
            // Check selection every 0.3s (balanced between responsiveness and battery)
            selectionTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                self?.checkSelection()
            }
        }

        private func checkSelection() {
            guard let interaction = interaction else { return }

            if interaction.hasActiveTextSelection {
                let text = interaction.selectedText
                if !text.isEmpty && text != parent.selectedText {
                    #if DEBUG
                    print("📝 [LIVE TEXT] Text selected: \(text.prefix(50))...")
                    #endif

                    DispatchQueue.main.async {
                        self.parent.onSelectionChange(text)
                    }
                }
            } else if !parent.selectedText.isEmpty {
                DispatchQueue.main.async {
                    self.parent.onSelectionChange("")
                }
            }
        }

        deinit {
            selectionTimer?.invalidate()
        }
    }
}

// MARK: - Toolbar Button (iOS 26 Liquid Glass)

struct ToolbarButton: View {
    let icon: String
    let label: String
    let isEnabled: Bool
    var tint: Color = .white
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            guard isEnabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isEnabled ? tint : .white.opacity(0.3))

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isEnabled ? .white.opacity(0.8) : .white.opacity(0.3))
            }
            .frame(width: 44, height: 44)
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                guard isEnabled else { return }
                withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

#Preview {
    if #available(iOS 16.0, *) {
        LiveTextQuoteCapture(
            bookContext: nil,
            onQuoteSaved: { text, page in
                print("Saved: \(text)")
            },
            onQuestionAsked: { question in
                print("Asked: \(question)")
            }
        )
    }
}
