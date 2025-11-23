import SwiftUI
import Vision
import VisionKit
import UIKit
import AVFoundation

// MARK: - Ambient Intelligence - Delegate Fix with iOS 26 Context Menu
struct AmbientTextCapture: View {
    @Binding var isPresented: Bool
    let bookContext: Book?
    let onQuoteSaved: (String, Int?) -> Void
    let onQuestionAsked: (String) -> Void

    @State private var capturedImage: UIImage?
    @State private var selectedText = ""
    @State private var showingMenu = false
    @State private var showingCamera = false
    @State private var pageNumber: Int?
    @State private var isAnalyzing = false
    @State private var isInitialized = false

    @Environment(\.dismiss) private var dismiss
    @AppStorage("experimentalCustomCamera") private var experimentalCustomCamera = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = capturedImage {
                // Use the original FixedLiveTextView that was working
                FixedLiveTextView(
                    image: image,
                    selectedText: $selectedText,
                    isAnalyzing: $isAnalyzing
                )
                .ignoresSafeArea(edges: .bottom)

                // Loading overlay
                if isAnalyzing {
                    loadingOverlay
                }

                // Add selection pills overlay
                selectionPillsOverlay
            } else {
                capturePrompt
            }
        }
        .overlay(alignment: .top) {
            navigationBar
        }
        .overlay(alignment: .bottom) {
            if !selectedText.isEmpty && !showingMenu {
                selectionBar
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            // Feature flag: Use experimental live quote capture or fallback to traditional flow
            if experimentalCustomCamera {
                #if DEBUG
                let _ = print("🚀 [AMBIENT] Launching LiveTextQuoteCapture (experimental)")
                #endif

                if #available(iOS 16.0, *) {
                    LiveTextQuoteCapture(
                        bookContext: bookContext,
                        onQuoteSaved: { text, page in
                            #if DEBUG
                            print("💾 [AMBIENT] Quote saved from LiveTextQuoteCapture")
                            #endif
                            // Direct save - no need for intermediate image
                            onQuoteSaved(text, page)
                            showingCamera = false
                            // Also dismiss AmbientTextCapture to go back to ambient mode
                            isPresented = false
                        },
                        onQuestionAsked: { question in
                            #if DEBUG
                            print("🤔 [AMBIENT] Question asked from LiveTextQuoteCapture")
                            #endif
                            // Direct question - no need for intermediate image
                            onQuestionAsked(question)
                            showingCamera = false
                            // Also dismiss AmbientTextCapture to go back to ambient mode
                            isPresented = false
                        }
                    )
                }
            } else {
                #if DEBUG
                let _ = print("📷 [AMBIENT] Launching traditional CameraCapture")
                #endif

                // Traditional flow: Capture image first, then select text
                CameraCapture { image in
                    if let image = image {
                        capturedImage = image
                        extractPageNumber(from: image)
                    }
                    showingCamera = false
                }
            }
        }
        .task {
            guard !isInitialized else { return }
            isInitialized = true

            // Lazy load - wait a moment for view to settle
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds

            // Only show camera if we don't have an image yet
            if capturedImage == nil {
                showingCamera = true
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onDisappear {
            // Clean up resources when view dismisses
            capturedImage = nil
            selectedText = ""
            isAnalyzing = false
        }
    }

    // MARK: - Capture Prompt
    private var capturePrompt: some View {
        ZStack {
            // Ambient gradient background
            AmbientChatGradientView()
                .opacity(0.6)
                .ignoresSafeArea()

            // Darkening overlay for readability
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Refined viewfinder icon with amber accent
                Image(systemName: "viewfinder")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    .symbolEffect(.pulse)

                VStack(spacing: 16) {
                    // Title using system font like session summary
                    Text("Ambient Intelligence")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(Color.white)

                    // Monospaced subheadline
                    Text("CAPTURE AND SELECT TEXT NATURALLY")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .kerning(1.2)
                        .foregroundStyle(Color.white.opacity(0.6))
                }

                Button {
                    showingCamera = true
                    SensoryFeedbackHelper.impact(.medium)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "camera")
                        Text("Capture Page")
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .glassEffect(in: .capsule)
                }
            }
        }
    }

    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                Text("Analyzing text...")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }
            .padding(32)
            .glassEffect(in: .rect(cornerRadius: 20))
        }
    }

    // MARK: - Selection Pills Overlay
    private var selectionPillsOverlay: some View {
        Group {
            if !selectedText.isEmpty {
                VStack {
                    Spacer()

                    HStack(spacing: 12) {
                        // Save Quote Button
                        Button {
                            // Capture the text before clearing it
                            let textToSave = selectedText
                            let page = pageNumber

                            // Clear selection first to avoid UI issues
                            selectedText = ""

                            // Haptic feedback
                            SensoryFeedbackHelper.impact(.light)

                            // Save the quote with captured values
                            if !textToSave.isEmpty {
                                onQuoteSaved(textToSave, page)
                            }

                            // Dismiss after a small delay to ensure UI updates
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                dismiss()
                            }
                        } label: {
                            Label("Save Quote", systemImage: "quote.bubble.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .glassEffect(in: .capsule)
                        }

                        // Ask AI Button
                        Button {
                            // Capture values before clearing
                            let textToAsk = selectedText
                            let question = generateSmartQuestion(for: textToAsk)

                            // Clear selection first
                            selectedText = ""

                            // Haptic feedback
                            SensoryFeedbackHelper.impact(.medium)

                            // Ask the question
                            if !textToAsk.isEmpty {
                                onQuestionAsked(question)
                            }

                            // Dismiss after a small delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                dismiss()
                            }
                        } label: {
                            Text("Ask Epilogue")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.orange)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .glassEffect(in: .capsule)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: !selectedText.isEmpty)
            }
        }
    }

    // MARK: - Navigation Bar
    private var navigationBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .glassEffect(in: .circle)
            }

            Spacer()

            Text(selectedText.isEmpty ? "Select text" : "\(selectedText.split(separator: " ").count) words")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            Spacer()

            Button {
                capturedImage = nil
                selectedText = ""
                showingCamera = true
            } label: {
                Image(systemName: "camera.rotate")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .glassEffect(in: .circle)
            }
        }
        .padding(.horizontal)
        .padding(.top, 60)
        .padding(.bottom, 12)
    }

    // MARK: - Selection Bar
    private var selectionBar: some View {
        HStack {
            Text("\(selectedText.split(separator: " ").count) words selected")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)

            Spacer()

            Button("Show Actions") {
                withAnimation {
                    showingMenu = true
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.blue)
        }
        .padding()
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [.clear, .black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }


    // MARK: - Helper Methods
    private func generateSmartQuestion(for text: String) -> String {
        let wordCount = text.split(separator: " ").count

        if wordCount < 10 {
            return "What does \"\(text)\" mean in this context?"
        } else if text.contains("?") {
            return "Can you explain this question and its implications?"
        } else if wordCount > 50 {
            return "Can you analyze this passage and explain its key themes?"
        } else {
            return "What is the significance of this text?"
        }
    }

    private func extractPageNumber(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }

        let request = VNRecognizeTextRequest { request, _ in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            for observation in observations {
                if let text = observation.topCandidates(1).first?.string,
                   let number = Int(text.trimmingCharacters(in: .punctuationCharacters)),
                   number > 0 && number < 10000 {
                    DispatchQueue.main.async {
                        self.pageNumber = number
                    }
                    break
                }
            }
        }

        request.recognitionLevel = .accurate
        DispatchQueue.global(qos: .userInitiated).async {
            try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        }
    }
}

// MARK: - Custom UIActivity Classes for Menu Items
class SaveQuoteActivity: UIActivity {
    override var activityType: UIActivity.ActivityType? {
        return UIActivity.ActivityType("com.epilogue.savequote")
    }

    override var activityTitle: String? {
        return "Save Quote"
    }

    override var activityImage: UIImage? {
        return UIImage(systemName: "quote.bubble.fill")
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return true
    }

    override func perform() {
        NotificationCenter.default.post(
            name: Notification.Name("TriggerQuoteSave"),
            object: nil
        )
        activityDidFinish(true)
    }
}

class AskAIActivity: UIActivity {
    override var activityType: UIActivity.ActivityType? {
        return UIActivity.ActivityType("com.epilogue.askai")
    }

    override var activityTitle: String? {
        return "Ask AI"
    }

    override var activityImage: UIImage? {
        return UIImage(systemName: "sparkles")
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return true
    }

    override func perform() {
        NotificationCenter.default.post(
            name: Notification.Name("TriggerAskAI"),
            object: nil
        )
        activityDidFinish(true)
    }
}

// MARK: - Fixed Live Text View
struct FixedLiveTextView: UIViewRepresentable {
    let image: UIImage
    @Binding var selectedText: String
    @Binding var isAnalyzing: Bool

    func makeUIView(context: Context) -> UIView {
        // Create container view to control sizing
        let containerView = UIView()
        containerView.backgroundColor = .clear

        let imageView = UIImageView()
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(imageView)

        // Add constraints to make image view fill container
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        // Create and configure interaction
        let interaction = ImageAnalysisInteraction()
        interaction.preferredInteractionTypes = [.textSelection]

        // Set delegate BEFORE adding interaction
        interaction.delegate = context.coordinator

        // Add interaction to image view
        imageView.addInteraction(interaction)

        // Store references
        context.coordinator.interaction = interaction
        context.coordinator.parent = self
        
        // Start monitoring for selection
        context.coordinator.startMonitoring()

        // Start analysis
        isAnalyzing = true
        Task {
            await analyzeImage(image: image, interaction: interaction)
        }

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private func analyzeImage(image: UIImage, interaction: ImageAnalysisInteraction) async {
        // Run analysis on background queue to avoid blocking UI
        await Task.detached(priority: .userInitiated) {
            let analyzer = ImageAnalyzer()
            let configuration = ImageAnalyzer.Configuration([.text])

            do {
                let analysis = try await analyzer.analyze(image, configuration: configuration)

                await MainActor.run {
                    interaction.analysis = analysis
                    self.isAnalyzing = false
                    #if DEBUG
                    print("✅ Analysis complete")
                    #endif
                }
            } catch {
                #if DEBUG
                print("❌ Analysis failed: \(error)")
                #endif
                await MainActor.run {
                    self.isAnalyzing = false
                }
            }
        }.value
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, ImageAnalysisInteractionDelegate {
        var parent: FixedLiveTextView?
        var interaction: ImageAnalysisInteraction?
        private var selectionTimer: Timer?
        
        func startMonitoring() {
            // Start a timer to check selection periodically as backup
            selectionTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                self?.checkSelectionStatus()
            }
        }
        
        private func checkSelectionStatus() {
            guard let interaction = interaction else { return }
            
            if interaction.hasActiveTextSelection {
                let text = interaction.selectedText
                if !text.isEmpty && text != parent?.selectedText {
                    #if DEBUG
                    print("⏱️ Timer detected selection: \(text)")
                    #endif
                    DispatchQueue.main.async { [weak self] in
                        self?.parent?.selectedText = text
                    }
                }
            }
        }

        // MARK: - ImageAnalysisInteractionDelegate
        // Use delegate methods instead of polling - MUCH more efficient

        func interaction(_ interaction: ImageAnalysisInteraction, shouldBeginAt point: CGPoint, for interactionType: ImageAnalysisInteraction.InteractionTypes) -> Bool {
            #if DEBUG
            print("🔍 Text selection interaction starting")
            #endif
            return true
        }

        func interaction(_ interaction: ImageAnalysisInteraction, didUpdateHighlightedRanges highlightedRanges: [Range<String.Index>]?) {
            // Called when selection changes
            #if DEBUG
            print("📝 Selection updated, checking text...")
            #endif
            updateSelection()
        }
        
        // Implement textSelectionDidChange which is more reliable
        func textSelectionDidChange(_ interaction: ImageAnalysisInteraction) {
            #if DEBUG
            print("✏️ Text selection changed")
            #endif
            updateSelection()
        }

        func interactionDidEnd(_ interaction: ImageAnalysisInteraction) {
            // Don't clear selection immediately - let user interact with buttons
            #if DEBUG
            print("🔚 Interaction ended")
            #endif
        }

        private func updateSelection() {
            guard let interaction = self.interaction else { return }

            if interaction.hasActiveTextSelection {
                let text = interaction.selectedText
                #if DEBUG
                print("📋 Selected text: \(text)")
                #endif
                if !text.isEmpty {
                    DispatchQueue.main.async { [weak self] in
                        self?.parent?.selectedText = text
                    }
                }
            } else {
                // Only clear if there's truly no selection
                DispatchQueue.main.async { [weak self] in
                    if self?.parent?.selectedText != "" {
                        #if DEBUG
                        print("🧹 Clearing selection")
                        #endif
                        self?.parent?.selectedText = ""
                    }
                }
            }
        }

        deinit {
            // Clean up references (delegate cleanup happens automatically)
            selectionTimer?.invalidate()
            interaction = nil
            parent = nil
        }
    }
}


// MARK: - Fallback DataScanner View
struct FallbackDataScannerView: View {
    let image: UIImage
    @Binding var selectedText: String
    let onTextSelected: (String) -> Void

    @State private var extractedText = ""
    @State private var isProcessing = true

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)

            if isProcessing {
                Color.black.opacity(0.7)
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Extracting text...")
                        .foregroundStyle(.white)
                }
            }
        }
        .onAppear {
            extractAllText()
        }
    }

    private func extractAllText() {
        guard let cgImage = image.cgImage else {
            isProcessing = false
            return
        }

        let request = VNRecognizeTextRequest { request, _ in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    isProcessing = false
                }
                return
            }

            let text = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ")

            DispatchQueue.main.async {
                extractedText = text
                selectedText = text
                isProcessing = false
                onTextSelected(text)
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            try? VNImageRequestHandler(cgImage: cgImage).perform([request])
        }
    }
}

// MARK: - Camera Capture
struct CameraCapture: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapture

        init(_ parent: CameraCapture) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.completion(info[.originalImage] as? UIImage)
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Sensory Feedback Helper
struct SensoryFeedbackHelper {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Smooth Custom Camera (Experimental)
// Replaces UIImagePickerController with custom AVFoundation camera for better UX

struct SmoothCameraCapture: View {
    let completion: (UIImage?) -> Void

    @StateObject private var cameraManager = SharedCameraManager()
    @Environment(\.dismiss) private var dismiss
    @State private var showCaptureButton = false
    @State private var isCapturing = false

    var body: some View {
        ZStack {
            // Camera preview
            if cameraManager.isSessionRunning {
                CameraPreviewRepresentable(session: cameraManager.session)
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else {
                // Loading state
                Color.black
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)

                            Text("Initializing camera...")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
            }

            // Page frame guide overlay
            PageFrameGuide()

            // Controls
            VStack {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .glassEffect(in: .circle)
                    }

                    Spacer()

                    // Debug indicator
                    #if DEBUG
                    Text("EXPERIMENTAL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.2))
                        .clipShape(Capsule())
                    #endif
                }
                .padding(.horizontal)
                .padding(.top, 16)

                Spacer()

                // Instructions
                if !isCapturing {
                    Text("Position page within frame")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .glassEffect(in: .capsule)
                        .opacity(showCaptureButton ? 1 : 0)
                        .padding(.bottom, 20)
                }

                // Capture button
                if !isCapturing {
                    Button {
                        capturePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(.white.opacity(0.5), lineWidth: 4)
                                .frame(width: 80, height: 80)

                            Circle()
                                .fill(.white)
                                .frame(width: 66, height: 66)
                        }
                    }
                    .disabled(!cameraManager.isSessionRunning)
                    .opacity(showCaptureButton && cameraManager.isSessionRunning ? 1 : 0.5)
                    .scaleEffect(showCaptureButton ? 1 : 0.8)
                    .padding(.bottom, 40)
                } else {
                    // Capturing state
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.3)

                        Text("Capturing...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.bottom, 60)
                }
            }
        }
        .onAppear {
            #if DEBUG
            print("🎥 [EXPERIMENT] SmoothCameraCapture appeared")
            #endif

            cameraManager.startSession()

            // Wait for camera to fully initialize before enabling capture
            // This prevents AVFoundation exceptions from premature capture attempts
            Task {
                // Give the session time to stabilize
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                // Double-check session is actually running
                guard cameraManager.isSessionRunning else {
                    #if DEBUG
                    print("❌ [EXPERIMENT] Session failed to start")
                    #endif
                    return
                }

                // Fade in capture button
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.3)) {
                        showCaptureButton = true
                    }
                }
            }
        }
        .onDisappear {
            #if DEBUG
            print("🎥 [EXPERIMENT] SmoothCameraCapture disappeared")
            #endif

            cameraManager.stopSession()
        }
    }

    private func capturePhoto() {
        // Safety check - ensure session is running
        guard cameraManager.isSessionRunning else {
            #if DEBUG
            print("❌ [EXPERIMENT] Capture blocked - session not running")
            #endif
            return
        }

        SensoryFeedbackHelper.impact(.medium)

        // Visual feedback
        withAnimation(.spring(response: 0.2)) {
            showCaptureButton = false
            isCapturing = true
        }

        #if DEBUG
        print("🎥 [EXPERIMENT] User tapped capture button")
        #endif

        cameraManager.capturePhoto { image in
            #if DEBUG
            print("🎥 [EXPERIMENT] Photo capture completed: \(image != nil)")
            #endif

            // Small delay for smoother UX
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                completion(image)
                dismiss()
            }
        }
    }
}

// MARK: - Camera Preview Representable
struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

// Custom UIView for camera preview to ensure proper layer handling
class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            if let session = session {
                previewLayer.session = session
            }
        }
    }

    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer()
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

// MARK: - Page Frame Guide
struct PageFrameGuide: View {
    @State private var pulseAnimation = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Darkened edges
                Color.black.opacity(0.5)
                    .reverseMask {
                        RoundedRectangle(cornerRadius: 20)
                            .frame(
                                width: geometry.size.width * 0.85,
                                height: geometry.size.height * 0.6
                            )
                    }

                // Frame outline with subtle pulse
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.8), lineWidth: 2)
                    .frame(
                        width: geometry.size.width * 0.85,
                        height: geometry.size.height * 0.6
                    )
                    .scaleEffect(pulseAnimation ? 1.01 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)

                // Corner guides
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white, lineWidth: 3)
                    .frame(
                        width: geometry.size.width * 0.85,
                        height: geometry.size.height * 0.6
                    )
                    .mask {
                        CornerGuideMask()
                    }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            pulseAnimation = true
        }
    }
}

// Corner guide mask for professional look
struct CornerGuideMask: View {
    var body: some View {
        GeometryReader { geometry in
            let cornerLength: CGFloat = 30

            ZStack {
                // Top-left
                Path { path in
                    path.move(to: CGPoint(x: 0, y: cornerLength))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: cornerLength, y: 0))
                }
                .stroke(lineWidth: 3)
                .position(x: cornerLength / 2, y: cornerLength / 2)

                // Top-right
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: cornerLength, y: 0))
                    path.addLine(to: CGPoint(x: cornerLength, y: cornerLength))
                }
                .stroke(lineWidth: 3)
                .position(x: geometry.size.width - cornerLength / 2, y: cornerLength / 2)

                // Bottom-left
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: cornerLength))
                    path.addLine(to: CGPoint(x: cornerLength, y: cornerLength))
                }
                .stroke(lineWidth: 3)
                .position(x: cornerLength / 2, y: geometry.size.height - cornerLength / 2)

                // Bottom-right
                Path { path in
                    path.move(to: CGPoint(x: cornerLength, y: 0))
                    path.addLine(to: CGPoint(x: cornerLength, y: cornerLength))
                    path.addLine(to: CGPoint(x: 0, y: cornerLength))
                }
                .stroke(lineWidth: 3)
                .position(x: geometry.size.width - cornerLength / 2, y: geometry.size.height - cornerLength / 2)
            }
        }
    }
}

// Note: reverseMask extension already defined in BookScannerView.swift