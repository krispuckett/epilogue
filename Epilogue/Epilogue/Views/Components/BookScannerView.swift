import SwiftUI
@preconcurrency import AVFoundation
import Vision
import UIKit
import CoreImage
import Combine
import OSLog

struct BookScannerView: View {
    @StateObject private var scanner = BookScannerService.shared
    @StateObject private var cameraManager = BookCameraManager()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var countdownTimer: Timer?
    
    @State private var scanState: ScanState = .scanning
    @State private var frameAlignment: FrameAlignment = .notAligned
    @State private var captureCountdown: Int = 3
    @State private var showManualOptions = false
    @State private var capturedImage: UIImage?
    @State private var pulseAnimation = false
    
    enum ScanState {
        case scanning
        case capturing
        case processing
        case results
    }
    
    enum FrameAlignment {
        case notAligned
        case partial
        case aligned
        
        var color: Color {
            switch self {
            case .notAligned: return .red.opacity(0.6)
            case .partial: return .orange.opacity(0.6)
            case .aligned: return .green
            }
        }
        
        var instruction: String {
            switch self {
            case .notAligned: return "Position book cover in frame"
            case .partial: return "Almost there..."
            case .aligned: return "Perfect! Hold steady"
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Camera view or loading state
            if cameraManager.isSessionRunning {
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else {
                // Loading state
                Color.black
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 20) {
                            SimpleProgressIndicator(scale: 1.5)
                            Text("Initializing camera...")
                                .font(.system(size: 16))
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }
            }
            
            // Dark overlay with cutout
            CameraOverlay(frameAlignment: frameAlignment)
            
            // Background blur when processing
            if scanState == .processing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            // UI Overlays
            VStack {
                // Top bar
                topBar
                
                Spacer()
                
                // Guidance and status
                VStack(spacing: 20) {
                    if scanState == .scanning {
                        guidanceView
                            .transition(.scale.combined(with: .opacity))
                    } else if scanState == .capturing {
                        capturingView
                            .transition(.scale.combined(with: .opacity))
                    } else if scanState == .processing {
                        processingView
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.bottom, 100)
            }
            
            // Manual capture button
            if scanState == .scanning {
                VStack {
                    Spacer()
                    manualCaptureButton
                        .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: frameAlignment) { _, newAlignment in
            if newAlignment == .aligned && scanState == .scanning {
                startAutoCapture()
            }
        }
        .onAppear {
            checkCameraPermission()
        }
        .onDisappear {
            countdownTimer?.invalidate()
            countdownTimer = nil
            cameraManager.stopSession()
        }
    }
    
    // MARK: - UI Components
    
    private var topBar: some View {
        HStack {
            Button {
                #if DEBUG
                print("🔴 Close button tapped")
                #endif
                countdownTimer?.invalidate()
                cameraManager.stopSession()
                scanner.reset()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
            }
            .contentShape(Circle())
            
            Spacer()
            
            Text("Scan Book Cover")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
            
            Spacer()
            
            // Placeholder for balance
            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    private var guidanceView: some View {
        VStack(spacing: 12) {
            // Alignment indicator
            HStack(spacing: 8) {
                Image(systemName: frameAlignment == .aligned ? "checkmark.circle.fill" : "viewfinder.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(frameAlignment.color)
                
                Text(frameAlignment.instruction)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
            .padding(.vertical, 10)
            .glassEffect(in: Capsule())
            
            // Additional tips
            if frameAlignment != .aligned {
                Text("Hold phone parallel to book cover")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
    }
    
    private var capturingView: some View {
        VStack(spacing: 16) {
            // Animated countdown
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(captureCountdown) / 3.0)
                    .stroke(
                        DesignSystem.Colors.primaryAccent,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: captureCountdown)
                
                // Countdown number
                Text("\(captureCountdown)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(DesignSystem.Animation.springStandard, value: pulseAnimation)
            }
            
            Text("Hold steady")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .strokeBorder(DesignSystem.Colors.primaryAccent.opacity(0.3), lineWidth: 0.5)
        }
    }
    
    private var processingView: some View {
        VStack(spacing: 24) {
            // Custom animated progress indicator
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 3)
                    .frame(width: 60, height: 60)
                
                // Animated progress ring
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primaryAccent,
                                Color(red: 1.0, green: 0.7, blue: 0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(pulseAnimation ? 360 : 0))
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: pulseAnimation)
                
                // Book icon in center
                Image(systemName: "book.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)
            }
            
            VStack(spacing: 8) {
                Text("Reading your book")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text(scanner.processingStatus)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(32)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        }
        .shadow(color: DesignSystem.Colors.primaryAccent.opacity(0.2), radius: 20, y: 10)
        .onAppear {
            pulseAnimation = true
        }
    }
    
    private var manualCaptureButton: some View {
        Button {
            captureManually()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 20))
                
                Text("Capture Manually")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, DesignSystem.Spacing.cardPadding)
            .padding(.vertical, 14)
            .glassEffect(in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(DesignSystem.Colors.textQuaternary, lineWidth: 0.5)
            }
        }
    }
    
    // MARK: - Methods
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraManager.startSession()
            cameraManager.onFrameCapture = { image in
                analyzeFrame(image)
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        cameraManager.startSession()
                        cameraManager.onFrameCapture = { image in
                            analyzeFrame(image)
                        }
                    }
                }
            }
        case .denied, .restricted:
            // Handle permission denied
            #if DEBUG
            print("Camera permission denied")
            #endif
        @unknown default:
            break
        }
    }
    
    private func analyzeFrame(_ image: UIImage) {
        // Use Vision to detect rectangles (book covers)
        guard let cgImage = image.cgImage else { return }
        
        let request = VNDetectRectanglesRequest { request, error in
            guard let results = request.results as? [VNRectangleObservation],
                  let rect = results.first else {
                frameAlignment = .notAligned
                return
            }
            
            // Check confidence and size
            let confidence = rect.confidence
            let size = rect.boundingBox.size
            
            // Determine alignment based on rectangle detection
            if confidence > 0.9 && size.width > 0.4 && size.height > 0.4 {
                frameAlignment = .aligned
            } else if confidence > 0.7 {
                frameAlignment = .partial
            } else {
                frameAlignment = .notAligned
            }
        }
        
        request.minimumConfidence = 0.5
        request.maximumObservations = 1
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
    
    private func startAutoCapture() {
        scanState = .capturing
        captureCountdown = 3
        
        // Cancel any existing timer
        countdownTimer?.invalidate()
        
        // Immediate countdown
        SensoryFeedback.light()
        
        // Slower countdown for better UX
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { timer in
            captureCountdown -= 1
            
            if captureCountdown > 0 {
                SensoryFeedback.light()
                withAnimation {
                    pulseAnimation.toggle()
                }
            } else {
                timer.invalidate()
                countdownTimer = nil
                performCapture()
            }
        }
    }
    
    private func captureManually() {
        SensoryFeedback.medium()
        performCapture()
    }
    
    private func performCapture() {
        #if DEBUG
        print("🟢 performCapture called")
        #endif
        
        // Add haptic feedback
        SensoryFeedback.medium()
        
        // Freeze the camera preview for a smoother transition
        cameraManager.capturePhoto { image in
            guard let image = image else { 
                #if DEBUG
                print("🔴 Failed to capture photo")
                #endif
                withAnimation(DesignSystem.Animation.springStandard) {
                    scanState = .scanning
                }
                return 
            }
            
            #if DEBUG
            print("🟢 Photo captured successfully")
            #endif
            capturedImage = image
            
            // Smooth transition to processing
            withAnimation(DesignSystem.Animation.springStandard) {
                scanState = .processing
            }
            
            SensoryFeedback.success()
            
            // Process with BookScannerService
            Task {
                #if DEBUG
                print("🔵 Processing captured image...")
                #endif
                
                // Ensure minimum processing time for smooth UX
                let startTime = Date()
                let info = await scanner.processScannedImage(image)
                
                // Ensure we've waited at least 0.8s for smooth UX
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed < 0.8 {
                    try? await Task.sleep(nanoseconds: UInt64((0.8 - elapsed) * 1_000_000_000))
                }
                
                #if DEBUG
                print("🔵 Extracted book info successfully")
                #endif
                
                if info.hasValidInfo {
                    #if DEBUG
                    print("🔵 Valid info found, preparing search...")
                    #endif
                    
                    // Set up the search
                    await scanner.searchWithExtractedInfo(info)
                    
                    // Smooth dismiss with fade
                    await MainActor.run {
                        withAnimation(.easeOut(duration: 0.2)) {
                            // The sheet will appear after this view dismisses
                            dismiss()
                        }
                    }
                } else {
                    #if DEBUG
                    print("🔴 No valid info extracted")
                    #endif
                    await MainActor.run {
                        withAnimation(DesignSystem.Animation.springStandard) {
                            scanState = .scanning
                        }
                        
                        // Show error toast
                        SensoryFeedback.warning()
                        // TODO: Show error message to user
                    }
                }
            }
        }
    }
    
    private func showManualSearchOption() {
        #if DEBUG
        print("🟡 No text detected, dismissing scanner")
        #endif
        scanState = .scanning
        // Reset and dismiss
        scanner.reset()
        dismiss()
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: BookCameraManager
    
    class PreviewView: UIView {
        private static let logger = Logger(subsystem: "com.epilogue.app", category: "CameraPreview")

        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
                Self.logger.error("Critical: Expected AVCaptureVideoPreviewLayer but got \(type(of: self.layer))")
                // This should never happen since layerClass is set correctly
                // Return a new instance as emergency fallback
                return AVCaptureVideoPreviewLayer()
            }
            return previewLayer
        }
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = PreviewView()
        view.videoPreviewLayer.session = cameraManager.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No update needed
    }
}

// MARK: - Camera Overlay

struct CameraOverlay: View {
    let frameAlignment: BookScannerView.FrameAlignment
    @State private var animateGuide = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background with cutout
                Color.black.opacity(0.6)
                    .reverseMask {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                            .frame(
                                width: geometry.size.width * 0.85,
                                height: geometry.size.height * 0.5
                            )
                    }
                
                // Guide frame
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .strokeBorder(frameAlignment.color, lineWidth: 3)
                    .frame(
                        width: geometry.size.width * 0.85,
                        height: geometry.size.height * 0.5
                    )
                    .overlay {
                        // Corner guides
                        cornerGuides
                            .foregroundStyle(frameAlignment.color)
                    }
                    .scaleEffect(animateGuide ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateGuide)
                    .onAppear {
                        animateGuide = true
                    }
            }
        }
    }
    
    private var cornerGuides: some View {
        GeometryReader { geometry in
            let cornerLength: CGFloat = 30
            let lineWidth: CGFloat = 4
            
            // Top-left
            Path { path in
                path.move(to: CGPoint(x: 0, y: cornerLength))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: cornerLength, y: 0))
            }
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            
            // Top-right
            Path { path in
                path.move(to: CGPoint(x: geometry.size.width - cornerLength, y: 0))
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                path.addLine(to: CGPoint(x: geometry.size.width, y: cornerLength))
            }
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            
            // Bottom-left
            Path { path in
                path.move(to: CGPoint(x: 0, y: geometry.size.height - cornerLength))
                path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                path.addLine(to: CGPoint(x: cornerLength, y: geometry.size.height))
            }
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            
            // Bottom-right
            Path { path in
                path.move(to: CGPoint(x: geometry.size.width - cornerLength, y: geometry.size.height))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height - cornerLength))
            }
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
    }
}

// MARK: - Camera Manager

@MainActor
class BookCameraManager: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    let session = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private var photoOutput = AVCapturePhotoOutput()
    private var photoCaptureDelegate: PhotoCaptureDelegate?
    
    var onFrameCapture: ((UIImage) -> Void)?
    private var lastFrameTime = Date()
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        // Configure session
        session.sessionPreset = .photo
        
        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else { 
            #if DEBUG
            print("❌ Failed to get camera device")
            #endif
            return 
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        // Configure camera for book scanning
        do {
            try camera.lockForConfiguration()
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }
            camera.unlockForConfiguration()
        } catch {
            #if DEBUG
            print("❌ Failed to configure camera: \(error)")
            #endif
        }
        
        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        // Add video output for real-time analysis
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
    }
    
    func startSession() {
        guard !session.isRunning else { return }
        
        // Start session on background queue
        let captureSession = session
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            captureSession.startRunning()
            
            DispatchQueue.main.async {
                self?.isSessionRunning = true
            }
        }
    }
    
    func stopSession() {
        if session.isRunning {
            session.stopRunning()
            isSessionRunning = false
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        #if DEBUG
        print("📸 capturePhoto called")
        #endif
        
        // Check if running on simulator
        #if targetEnvironment(simulator)
        #if DEBUG
        print("⚠️ Running on simulator - using mock capture")
        #endif
        // For simulator testing, just return a mock success after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            #if DEBUG
            print("📸 Mock capture complete (simulator)")
            #endif
            // Return nil to trigger manual search in simulator
            completion(nil)
        }
        #else
        
        guard session.isRunning else {
            #if DEBUG
            print("❌ Session not running")
            #endif
            completion(nil)
            return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        
        #if DEBUG
        print("📸 Capturing photo with settings...")
        #endif
        
        // Store delegate to prevent deallocation
        photoCaptureDelegate = PhotoCaptureDelegate { [weak self] image in
            #if DEBUG
            print("📸 Photo delegate called with image: \(image != nil)")
            #endif
            DispatchQueue.main.async {
                completion(image)
                self?.photoCaptureDelegate = nil // Clean up
            }
        }
        
        photoOutput.capturePhoto(with: settings, delegate: photoCaptureDelegate!)
        #endif
    }
}

// MARK: - Video Output Delegate

extension BookCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Throttle frame analysis to every 0.5 seconds to reduce CPU usage
        let now = Date()
        guard now.timeIntervalSince(lastFrameTime) > 0.5 else { return }
        lastFrameTime = now
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        let image = UIImage(cgImage: cgImage)
        
        DispatchQueue.main.async {
            self.onFrameCapture?(image)
        }
    }
}

// MARK: - Photo Capture Delegate

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void
    
    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        #if DEBUG
        print("📸 PhotoCaptureDelegate - didFinishProcessingPhoto called")
        #endif
        
        if let error = error {
            #if DEBUG
            print("❌ Photo capture error: \(error)")
            #endif
            completion(nil)
            return
        }
        
        guard let data = photo.fileDataRepresentation() else {
            #if DEBUG
            print("❌ No photo data")
            #endif
            completion(nil)
            return
        }
        
        guard let image = UIImage(data: data) else {
            #if DEBUG
            print("❌ Failed to create UIImage from data")
            #endif
            completion(nil)
            return
        }
        
        #if DEBUG
        print("✅ Photo captured successfully, size: \(image.size)")
        #endif
        completion(image)
    }
}

// MARK: - Helper Extensions

extension View {
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle()
                .overlay {
                    mask()
                        .blendMode(.destinationOut)
                }
        }
    }
}
