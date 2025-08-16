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
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background for camera
                Color.black
                    .ignoresSafeArea()
                
                // Unified camera view that detects both
                CameraScannerView(
                    onBookFound: onBookFound,
                    isProcessing: $isProcessing,
                    detectionStatus: $detectionStatus
                )
                .ignoresSafeArea()
                
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
                        // Visual scanning frame - Simple and clean
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 3)
                            .frame(width: 280, height: 380)
                            .overlay(
                                // Corner markers
                                Group {
                                    // Top left
                                    Path { path in
                                        path.move(to: CGPoint(x: 0, y: 30))
                                        path.addLine(to: CGPoint(x: 0, y: 0))
                                        path.addLine(to: CGPoint(x: 30, y: 0))
                                    }
                                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 4)
                                    .frame(width: 30, height: 30)
                                    .position(x: 15, y: 15)
                                    
                                    // Top right
                                    Path { path in
                                        path.move(to: CGPoint(x: 0, y: 0))
                                        path.addLine(to: CGPoint(x: 30, y: 0))
                                        path.addLine(to: CGPoint(x: 30, y: 30))
                                    }
                                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 4)
                                    .frame(width: 30, height: 30)
                                    .position(x: 265, y: 15)
                                    
                                    // Bottom left
                                    Path { path in
                                        path.move(to: CGPoint(x: 0, y: 0))
                                        path.addLine(to: CGPoint(x: 0, y: 30))
                                        path.addLine(to: CGPoint(x: 30, y: 30))
                                    }
                                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 4)
                                    .frame(width: 30, height: 30)
                                    .position(x: 15, y: 365)
                                    
                                    // Bottom right
                                    Path { path in
                                        path.move(to: CGPoint(x: 30, y: 0))
                                        path.addLine(to: CGPoint(x: 30, y: 30))
                                        path.addLine(to: CGPoint(x: 0, y: 30))
                                    }
                                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 4)
                                    .frame(width: 30, height: 30)
                                    .position(x: 265, y: 365)
                                }
                            )
                        
                        // Status text
                        Text(detectionStatus)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .glassEffect()
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
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
                                .glassEffect()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Manual search button
                        Button {
                            // Show search sheet directly
                            showBookSearch = true
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Search")
                            }
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .glassEffect()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 20)
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
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $bookScanner.showSearchResults) {
            BookSearchSheet(
                searchQuery: bookScanner.extractedText,
                onBookSelected: { book in
                    onBookFound(book)
                    bookScanner.reset()
                    dismiss()
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
    
    func makeUIViewController(context: Context) -> CameraScannerViewController {
        let controller = CameraScannerViewController()
        controller.onBookFound = onBookFound
        controller.isProcessing = $isProcessing
        controller.detectionStatus = $detectionStatus
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraScannerViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Camera Scanner View Controller
class CameraScannerViewController: UIViewController {
    var onBookFound: ((Book) -> Void)?
    var isProcessing: Binding<Bool>?
    var detectionStatus: Binding<String>?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var processingISBN = false
    private var rectangleDetectionTimer: Timer?
    private var consecutiveDetections = 0
    private var lastRectangleCheck = Date()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("📸 CameraScannerViewController viewDidLoad")
        setupCamera()
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
            let scanner = BookScannerService.shared
            let bookInfo = await scanner.processScannedImage(image)
            
            if bookInfo.hasValidInfo {
                // Search for the book
                await scanner.searchWithExtractedInfo(bookInfo)
                
                // Wait a moment for search to complete
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Show the search results sheet
                await MainActor.run { [weak self] in
                    // The BookScannerService will set showSearchResults to true
                    // which triggers the sheet in this view
                    self?.isProcessing?.wrappedValue = false
                    self?.captureSession?.startRunning()
                    self?.consecutiveDetections = 0
                    
                    // Don't dismiss - the sheet will show over the scanner
                }
            } else {
                await MainActor.run { [weak self] in
                    self?.isProcessing?.wrappedValue = false
                    self?.captureSession?.startRunning()
                    self?.detectionStatus?.wrappedValue = "Could not read book cover. Try ISBN."
                    self?.consecutiveDetections = 0
                }
            }
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
        
        // Haptic feedback
        HapticManager.shared.mediumTap()
        
        // Stop camera for processing
        captureSession?.stopRunning()
        
        // Search for book by ISBN using Google Books API
        Task {
            print("📚 Searching for ISBN: \(stringValue)")
            await MainActor.run { [weak self] in
                self?.detectionStatus?.wrappedValue = "Searching for ISBN \(stringValue)..."
            }
            
            let googleBooks = GoogleBooksService()
            if let book = await googleBooks.searchBookByISBN(stringValue) {
                print("✅ Found book: \(book.title)")
                // Found book - call the callback directly
                await MainActor.run { [weak self] in
                    self?.onBookFound?(book)
                    self?.processingISBN = false
                }
            } else {
                print("❌ ISBN not found, showing search sheet")
                // Show search sheet with ISBN query
                await MainActor.run { [weak self] in
                    // Post notification to show search sheet
                    NotificationCenter.default.post(
                        name: Notification.Name("ShowBookSearchFromScanner"),
                        object: "isbn:\(stringValue)"
                    )
                    
                    // Reset state
                    self?.processingISBN = false
                    self?.isProcessing?.wrappedValue = false
                    self?.captureSession?.startRunning()
                }
            }
        }
    }
}