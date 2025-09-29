import SwiftUI
import AVFoundation
import Vision

struct EnhancedBookScannerView: View {
    let onBookFound: (Book) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var bookScanner = BookScannerService.shared
    @State private var isProcessing = false
    @State private var detectionStatus = "Position book cover or ISBN barcode"
    @State private var lastScannedISBN: String?
    @State private var showBookSearch = false
    @State private var searchQuery = ""
    @State private var hasRequestedPermission = false
    
    // Camera control states
    @State private var isTorchOn = false
    @State private var isExposureLocked = false
    @State private var focusPoint: CGPoint? = nil
    @State private var showFocusAnimation = false
    
    // Haptic generators
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background for camera
                Color.black
                    .ignoresSafeArea()
                
                // Unified camera view that detects both
                CameraScannerView(
                    onBookFound: onBookFound,
                    isProcessing: $isProcessing,
                    detectionStatus: $detectionStatus,
                    isTorchOn: $isTorchOn,
                    isExposureLocked: $isExposureLocked,
                    focusPoint: $focusPoint,
                    showFocusAnimation: $showFocusAnimation
                )
                .ignoresSafeArea()
                .onTapGesture { location in
                    focusPoint = location
                    showFocusAnimation = true
                    lightImpact.impactOccurred()
                }
                
                // Top gradient overlay for depth (like ambient mode)
                VStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.8),
                            Color.black.opacity(0.4),
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                    .ignoresSafeArea()
                    
                    Spacer()
                }
                .allowsHitTesting(false)
                
                // Overlay UI
                VStack {
                    Spacer()
                    
                    // Scanning guidance overlay
                    VStack(spacing: 20) {
                        // Visual scanning frame - Elegant rounded design
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.primaryAccent,
                                        DesignSystem.Colors.primaryAccent.opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 280, height: 380)
                            .shadow(color: DesignSystem.Colors.primaryAccent.opacity(0.3), radius: 10)
                        
                        // Status text with icon
                        HStack(spacing: 10) {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "viewfinder")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                            }

                            Text(detectionStatus)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .glassEffect(in: Capsule())
                    }
                    
                    Spacer()
                    
                    // Camera controls
                    HStack(spacing: 16) {
                        // Torch toggle
                        Button {
                            isTorchOn.toggle()
                            lightImpact.impactOccurred()
                        } label: {
                            Image(systemName: isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(isTorchOn ? .yellow : .white)
                                .frame(width: 44, height: 44)
                                .glassEffect(in: Circle())
                        }
                        
                        // Exposure lock
                        Button {
                            isExposureLocked.toggle()
                            lightImpact.impactOccurred()
                        } label: {
                            Image(systemName: isExposureLocked ? "sun.max.fill" : "sun.max")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(isExposureLocked ? .orange : .white)
                                .frame(width: 44, height: 44)
                                .glassEffect(in: Circle())
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    
                    // Action buttons at bottom
                    HStack(spacing: 12) {
                        // Cancel button
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .glassEffect(in: Capsule())
                        }

                        // Manual search button with accent border
                        Button {
                            // Show search sheet directly
                            showBookSearch = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Search")
                            }
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .glassEffect(in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                DesignSystem.Colors.primaryAccent.opacity(0.5),
                                                DesignSystem.Colors.primaryAccent.opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    .padding(.bottom, 30)
                }
                
                if isProcessing {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Identifying book...")
                            .foregroundStyle(.white)
                    }
                }
                
                // Focus animation overlay
                if showFocusAnimation, let point = focusPoint {
                    FocusIndicatorView(at: point)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showFocusAnimation = false
                            }
                        }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            checkCameraPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowBookSearchFromScanner"))) { notification in
            if let query = notification.object as? String {
                searchQuery = query
                showBookSearch = true
            }
        }
        .sheet(isPresented: $showBookSearch) {
            BookSearchSheet(
                searchQuery: searchQuery,
                onBookSelected: { book in
                    onBookFound(book)
                    showBookSearch = false
                    // Don't dismiss scanner - let user continue scanning or manually close
                    
                    // Reset status after delay (removed local status update since LibraryView shows toast)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        detectionStatus = "Position book cover or ISBN barcode"
                    }
                }
            )
        }
        .sheet(isPresented: $bookScanner.showSearchResults) {
            BookSearchSheet(
                searchQuery: bookScanner.extractedText,
                onBookSelected: { book in
                    onBookFound(book)
                    bookScanner.reset()
                    // Don't dismiss scanner - let user continue scanning or manually close
                    
                    // Reset status after delay (removed local status update since LibraryView shows toast)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        detectionStatus = "Position book cover or ISBN barcode"
                    }
                }
            )
        }
    }
    
    private func checkCameraPermission() {
        guard !hasRequestedPermission else { return }
        hasRequestedPermission = true
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("📸 Camera already authorized")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("📸 Camera permission granted")
                    } else {
                        print("❌ Camera permission denied")
                        detectionStatus = "Camera access required"
                    }
                }
            }
        case .denied, .restricted:
            print("❌ Camera access denied or restricted")
            detectionStatus = "Camera access required. Enable in Settings."
        @unknown default:
            break
        }
    }
}

// MARK: - Camera Scanner View
struct CameraScannerView: UIViewControllerRepresentable {
    let onBookFound: (Book) -> Void
    @Binding var isProcessing: Bool
    @Binding var detectionStatus: String
    @Binding var isTorchOn: Bool
    @Binding var isExposureLocked: Bool
    @Binding var focusPoint: CGPoint?
    @Binding var showFocusAnimation: Bool
    
    func makeUIViewController(context: Context) -> CameraScannerViewController {
        let controller = CameraScannerViewController()
        controller.onBookFound = onBookFound
        controller.isProcessing = $isProcessing
        controller.detectionStatus = $detectionStatus
        controller.torchBinding = $isTorchOn
        controller.exposureBinding = $isExposureLocked
        controller.focusBinding = $focusPoint
        controller.focusAnimationBinding = $showFocusAnimation
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraScannerViewController, context: Context) {
        uiViewController.updateCameraControls()
    }
}

// MARK: - Focus Indicator View
struct FocusIndicatorView: View {
    let at: CGPoint
    @State private var scale: CGFloat = 1.5
    @State private var opacity: Double = 0
    
    var body: some View {
        Circle()
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 80, height: 80)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(at)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 0.8
                    opacity = 1
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        opacity = 0
                    }
                }
            }
    }
}

// MARK: - Camera Scanner View Controller
class CameraScannerViewController: UIViewController {
    var onBookFound: ((Book) -> Void)?
    var isProcessing: Binding<Bool>?
    var detectionStatus: Binding<String>?
    var torchBinding: Binding<Bool>?
    var exposureBinding: Binding<Bool>?
    var focusBinding: Binding<CGPoint?>?
    var focusAnimationBinding: Binding<Bool>?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoDevice: AVCaptureDevice?
    private var processingISBN = false
    private var rectangleDetectionTimer: Timer?
    private var consecutiveDetections = 0
    private var lastRectangleCheck = Date()
    
    // Feature print for similarity matching
    private var featurePrintRequest: VNGenerateImageFeaturePrintRequest?
    private var capturedFeaturePrint: VNFeaturePrintObservation?
    
    // Haptic generators
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("📸 CameraScannerViewController viewDidLoad")
        setupCamera()
        setupFeaturePrint()
        
        // Prepare haptic generators
        mediumImpact.prepare()
        heavyImpact.prepare()
        notificationFeedback.prepare()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    private func setupCamera() {
        print("📸 Setting up camera")
        
        // Don't check permission here - just set up
        // Permission will be checked in the SwiftUI view
        
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession,
              let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            print("❌ Failed to get video device")
            return
        }
        
        videoDevice = videoCaptureDevice
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return
        }
        
        // Add metadata output for barcode scanning
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            // IMPORTANT: Set delegate AFTER adding output to session
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            
            // For ISBN barcode scanning - also add more barcode types
            // IMPORTANT: Set metadata types AFTER adding output
            var barcodeTypes: [AVMetadataObject.ObjectType] = []
            if metadataOutput.availableMetadataObjectTypes.contains(.ean13) {
                barcodeTypes.append(.ean13)
            }
            if metadataOutput.availableMetadataObjectTypes.contains(.ean8) {
                barcodeTypes.append(.ean8)
            }
            if metadataOutput.availableMetadataObjectTypes.contains(.code128) {
                barcodeTypes.append(.code128)
            }
            if metadataOutput.availableMetadataObjectTypes.contains(.code39) {
                barcodeTypes.append(.code39)
            }
            if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
                barcodeTypes.append(.qr)
            }
            
            if !barcodeTypes.isEmpty {
                metadataOutput.metadataObjectTypes = barcodeTypes
                print("✅ Set barcode types: \(barcodeTypes)")
            } else {
                print("❌ No barcode types available")
            }
        } else {
            print("❌ Could not add metadata output")
        }
        
        // Add photo output for visual book scanning
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        // Add video output for rectangle detection
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
            print("✅ Added video output for rectangle detection")
        } else {
            print("❌ Could not add video output")
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
            DispatchQueue.main.async {
                print("✅ Camera session started")
            }
        }
    }
    
    // MARK: - Feature Print Setup
    private func setupFeaturePrint() {
        featurePrintRequest = VNGenerateImageFeaturePrintRequest()
    }
    
    // MARK: - Camera Control Methods
    func updateCameraControls() {
        guard let device = videoDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Update torch
            if device.hasTorch {
                device.torchMode = (torchBinding?.wrappedValue ?? false) ? .on : .off
            }
            
            // Update exposure
            if exposureBinding?.wrappedValue ?? false {
                // Lock exposure at current values
                if device.isExposureModeSupported(.locked) {
                    device.exposureMode = .locked
                }
            } else {
                // Auto exposure
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Failed to update camera controls: \(error)")
        }
    }
    
    // MARK: - Touch Handling for Focus
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let device = videoDevice else { return }
        
        let touchPoint = touch.location(in: view)
        let devicePoint = previewLayer?.captureDevicePointConverted(fromLayerPoint: touchPoint) ?? .zero
        
        do {
            try device.lockForConfiguration()
            
            // Set focus point
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }
            
            // Set exposure point
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
            
            // Update UI
            focusBinding?.wrappedValue = touchPoint
            focusAnimationBinding?.wrappedValue = true
            
            // Light haptic for focus
            let impactGenerator = UIImpactFeedbackGenerator(style: .light)
            impactGenerator.prepare()
            impactGenerator.impactOccurred()
            
        } catch {
            print("Focus error: \(error)")
        }
    }
}

// MARK: - Video Data Delegate for Rectangle Detection
extension CameraScannerViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Throttle detection to avoid excessive processing
        guard Date().timeIntervalSince(lastRectangleCheck) > 0.5,
              !processingISBN,
              isProcessing?.wrappedValue == false else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Detect rectangles for book covers
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNRectangleObservation],
                  let rect = results.first,
                  rect.confidence > 0.8 else {
                DispatchQueue.main.async {
                    self?.consecutiveDetections = 0
                }
                return
            }
            
            // Book cover detected with high confidence
            DispatchQueue.main.async {
                self?.consecutiveDetections += 1
                self?.detectionStatus?.wrappedValue = "Book cover detected - hold steady"
                
                // Medium haptic on detection
                if self?.consecutiveDetections == 1 {
                    self?.mediumImpact.impactOccurred()
                }
                
                // After 3 consecutive detections, capture the photo
                if self?.consecutiveDetections ?? 0 >= 3 {
                    self?.captureBookPhoto()
                }
            }
        }
        
        request.minimumConfidence = 0.7
        request.maximumObservations = 1
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
        
        lastRectangleCheck = Date()
    }
    
    private func captureBookPhoto() {
        guard let photoOutput = photoOutput,
              isProcessing?.wrappedValue == false else { 
            print("⚠️ Already processing or no photo output")
            return 
        }
        
        print("📸 Capturing book photo...")
        isProcessing?.wrappedValue = true
        detectionStatus?.wrappedValue = "Capturing book cover..."
        
        // Heavy haptic on capture
        heavyImpact.impactOccurred()
        
        // Don't stop the session until after capture
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - Photo Capture Delegate
extension CameraScannerViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("❌ Photo capture error: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.isProcessing?.wrappedValue = false
                self?.captureSession?.startRunning()
                self?.detectionStatus?.wrappedValue = "Capture failed. Try again."
            }
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            print("❌ Failed to get image data")
            DispatchQueue.main.async { [weak self] in
                self?.isProcessing?.wrappedValue = false
                self?.captureSession?.startRunning()
                self?.detectionStatus?.wrappedValue = "Capture failed. Try again."
            }
            return
        }
        
        print("✅ Photo captured successfully")
        
        // Stop the session after successful capture
        captureSession?.stopRunning()
        
        // Process the captured image with BookScannerService
        Task {
            // Generate feature print for similarity matching
            if let cgImage = image.cgImage {
                await generateFeaturePrint(from: cgImage)
            }
            
            let scanner = BookScannerService.shared
            scanner.capturedFeaturePrint = self.capturedFeaturePrint
            let bookInfo = await scanner.processScannedImage(image)
            
            if bookInfo.hasValidInfo {
                // Search for the book
                await scanner.searchWithExtractedInfo(bookInfo)
                
                // Wait a moment for search to complete
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Show the search results sheet
                await MainActor.run { [weak self] in
                    // Success haptic feedback
                    self?.notificationFeedback.notificationOccurred(.success)
                    
                    // The BookScannerService will set showSearchResults to true
                    // which triggers the sheet in this view
                    self?.isProcessing?.wrappedValue = false
                    self?.consecutiveDetections = 0
                    
                    // Start camera on background thread
                    if let session = self?.captureSession {
                        DispatchQueue.global(qos: .userInitiated).async {
                            session.startRunning()
                        }
                    }
                    
                    // Don't dismiss - the sheet will show over the scanner
                }
            } else {
                await MainActor.run { [weak self] in
                    // Error haptic feedback
                    self?.notificationFeedback.notificationOccurred(.error)
                    
                    self?.isProcessing?.wrappedValue = false
                    self?.detectionStatus?.wrappedValue = "Could not read book cover. Try ISBN."
                    self?.consecutiveDetections = 0
                    
                    // Start camera on background thread
                    if let session = self?.captureSession {
                        DispatchQueue.global(qos: .userInitiated).async {
                            session.startRunning()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Feature Print Generation
    private func generateFeaturePrint(from cgImage: CGImage) async {
        guard let request = featurePrintRequest else { return }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            if let results = request.results as? [VNFeaturePrintObservation],
               let featurePrint = results.first {
                self.capturedFeaturePrint = featurePrint
                print("✅ Generated feature print for cover matching")
            }
        } catch {
            print("❌ Failed to generate feature print: \(error)")
        }
    }
}

// MARK: - Metadata Delegate for Barcode Scanning
extension CameraScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    
    private func findParentViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Remove excessive logging - only log when we have objects
        guard !metadataObjects.isEmpty else { return }
        
        // Don't process if already processing
        guard !processingISBN else {
            return
        }
        
        // Get first metadata object
        guard let metadataObject = metadataObjects.first else {
            return
        }
        
        // Log the type to see what we're detecting
        let typeString = metadataObject.type.rawValue
        
        // Cast to readable code
        guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else {
            print("❌ Could not cast \(typeString) to readable code")
            return
        }
        
        // Get string value
        guard let stringValue = readableObject.stringValue, !stringValue.isEmpty else {
            print("❌ No string value in \(typeString)")
            return
        }
        
        // Check if this is actually an ISBN (13 or 10 digits)
        let digitsOnly = stringValue.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        guard digitsOnly.count == 13 || digitsOnly.count == 10 else {
            print("⚠️ Barcode '\(stringValue)' is not an ISBN (wrong length: \(digitsOnly.count))")
            return
        }
        
        print("📖 ISBN DETECTED: \(stringValue)")
        
        // Update status
        DispatchQueue.main.async { [weak self] in
            self?.detectionStatus?.wrappedValue = "ISBN detected: \(stringValue)"
        }
        
        // Prevent duplicate processing
        processingISBN = true
        isProcessing?.wrappedValue = true
        
        // Heavy haptic feedback for successful ISBN scan
        heavyImpact.impactOccurred()
        
        // Stop camera for processing
        captureSession?.stopRunning()
        
        // Always show search sheet for ISBN to let user choose cover
        Task {
            print("📚 ISBN \(stringValue) detected - showing search sheet")
            await MainActor.run { [weak self] in
                self?.detectionStatus?.wrappedValue = "Found ISBN - showing results..."
                
                // Always show search sheet with ISBN query
                NotificationCenter.default.post(
                    name: Notification.Name("ShowBookSearchFromScanner"),
                    object: "isbn:\(stringValue)"
                )
                
                // Reset state
                self?.processingISBN = false
                self?.isProcessing?.wrappedValue = false
                
                // Start camera on background thread
                if let session = self?.captureSession {
                    DispatchQueue.global(qos: .userInitiated).async {
                        session.startRunning()
                    }
                }
            }
        }
    }
}